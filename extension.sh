#!/bin/bash -e
# shellcheck disable=SC2034

# Installs, updates and removes extensions with their dependencies.
#
# An extension is a git repository. Its versions are its semver tags (1.2.3), the default branch is the version "dev".
# Its extension.json declares its name, the Anodosys version it needs, the extensions it requires and where to find
# them when no registry knows them:
#   { "name": "magento", "anodosys": ">=3.0", "requires": { "fewedev": "^1.0" }, "sources": { "fewedev": "fewe-dev/anodosys" } }
#
# Extensions are found by name in registries: git repositories (or local directories or files) with a registry.json
#   { "extensions": { "cosyses": { "url": "https://github.com/cosyses/anodosys.git", "description": "..." } } }
# The registries of the user (~/.anodosys/registries.json) come first, then the shared ones (registries.json of the
# installation), then the public registry. A source is a name, a git url, a local path or a GitHub shorthand owner/repo.
#
# Every version is installed into <base>/var/extension/<name>/<version>, and <base>/extension/<name> links to the
# installed one, so Anodosys finds it like before. <base>/extensions.json records version, url, commit and whether the
# extension was requested or installed as a dependency. <base> is the installation (when run as root, shared by all
# users) or ~/.anodosys.

usage()
{
cat >&2 << EOF

usage: ads extension <ACTION> [ARGUMENTS] [OPTIONS]

ACTION:
  install <source>[@<constraint>]...  Install extensions and their dependencies, source is a name from a registry,
                                      a git url, a GitHub shorthand owner/repo or a local path
  install                             Install the extensions the system in this directory requires ("extensions"
                                      in its ads.json)
  update [<name>...]                  Update all or the given extensions to the newest matching versions
  remove <name>...                    Remove extensions and the dependencies nothing else requires
  list                                List the installed extensions
  outdated                            List the installed extensions that have newer versions
  search [<text>]                     List the extensions of all registries
  link <path>                         Use a local checkout as extension (for development)
  unlink <name>                       Remove a linked checkout
  check                               Check that every installed extension has what it requires
  registry list|add <url>|remove <url>  Manage the registries

OPTIONS:
  --name <name>  Name of an extension installed from a url or path, when its extension.json has no name
  --file <file>  Configuration of the system, instead of the one found in this directory
  --force        Replace an existing extension or remove an extension that others require

The extensions every registered system requires are kept to its constraints, a system configuration lists them as
  "extensions": { "laravel": "^1.0", "private": { "version": "^2.0", "source": "git@github.com:company/private.git" } }

CONSTRAINTS:
  ^1.2 (>=1.2.0 <2.0.0), ~1.2 (>=1.2.0 <1.3.0), 1.2.*, >=1.2 <2, 1.2.3, dev (the default branch)

Example: ads extension install fewedev
Example: ads extension install fewedev@^1.2
Example: ads extension install fewe-dev/anodosys
Example: ads extension registry add git@github.com:company/anodosys-registry.git
EOF
}

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi

anodosysPath=$(cd -P "$(dirname "${scriptName}")" && pwd)

for requiredCommand in git jq flock; do
  if ! command -v "${requiredCommand}" >/dev/null 2>&1; then
    >&2 echo "Please install required command: ${requiredCommand}"
    exit 1
  fi
done

source "${anodosysPath}/lib/extension/version.sh"
source "${anodosysPath}/lib/extension/check.sh"

# installed releases share their extensions so they survive updates
anodosysExtensionPath="${anodosysPath}/extension"
if [[ -L "$(dirname "${anodosysPath}")/current" ]]; then
  anodosysExtensionPath="$(dirname "${anodosysPath}")/extension"
fi
sharedBasePath=$(dirname "${anodosysExtensionPath}")

currentUser=$(whoami)
currentUserHome=$(getent passwd "${currentUser}" | cut -d: -f6)
anodosysUserPath="${ANODOSYS_USER_PATH:-${currentUserHome}/.anodosys}"
mkdir -p "${anodosysUserPath}"

if [[ $(id -u) == 0 ]]; then
  basePath="${sharedBasePath}"
  otherBasePath=
else
  basePath="${anodosysUserPath}"
  otherBasePath="${sharedBasePath}"
fi

installPath="${basePath}/extension"
storePath="${basePath}/var/extension"
lockFile="${basePath}/extensions.json"
registriesFile="${basePath}/registries.json"
registryCachePath="${anodosysUserPath}/var/registry"
defaultRegistry="${ANODOSYS_REGISTRY-https://github.com/anodosys/registry.git}"

mkdir -p "${installPath}" "${storePath}" "${registryCachePath}"

# no password prompts of git, a private repository without access fails instead
export GIT_TERMINAL_PROMPT=0

namePattern='^[A-Za-z0-9][A-Za-z0-9_.-]*$'
shorthandPattern='^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+$'
separator=$'\x1f'

fail()
{
  >&2 echo "$*"
  exit 1
}

# --- arguments ---

force=0
optionName=
optionFile=
positional=()
while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    -h|--help|-\?|help) usage; exit 0;;
    --force|-f) force=1;;
    --name) optionName="${2}"; shift;;
    --name=*) optionName="${1#--name=}";;
    --file) optionFile="${2}"; shift;;
    --file=*) optionFile="${1#--file=}";;
    -*) >&2 echo "Unknown option: ${1}"; usage; exit 1;;
    *) positional+=( "${1}" );;
  esac
  shift
done
set -- "${positional[@]}"

if [[ -n "${optionFile}" ]] && [[ ! -f "${optionFile}" ]]; then
  fail "Could not find configuration at: ${optionFile}"
fi

action="${1}"
if [[ -z "${action}" ]]; then
  >&2 echo "No action defined!"
  usage
  exit 1
fi
shift

# --- state ---

declare -A lockVersion=()
declare -A lockUrl=()
declare -A lockExplicit=()
declare -A lockConstraint=()
declare -A installedVersion=()
declare -A fixedVersion=()
declare -A fixedPath=()
declare -A fixedScope=()
declare -A selected=()
declare -A selectedUrl=()
declare -A requestConstraint=()
declare -A requestUrl=()
declare -A requested=()
declare -A upgrade=()
declare -A removing=()
declare -A replacing=()
declare -A refetched=()
declare -A constraints=()
declare -A needed=()
declare -A sourceHints=()
declare -A resolvedSources=()
declare -A remoteVersions=()
declare -A remoteTags=()
declare -A registryUrl=()
declare -A registryDescription=()
declare -A registrySource=()
projectLines=()
registriesLoaded=0
upgradeAll=0
chosenVersion=
lookupUrl=

loadLock()
{
  local name
  local version
  local url
  local explicit
  local constraint

  if [[ ! -s "${lockFile}" ]]; then
    return 0
  fi

  while IFS="${separator}" read -r name version url explicit constraint; do
    if [[ -n "${name}" ]]; then
      lockVersion["${name}"]="${version}"
      lockUrl["${name}"]="${url}"
      lockExplicit["${name}"]="${explicit}"
      lockConstraint["${name}"]="${constraint}"
    fi
  done < <(jq -r --arg separator "${separator}" 'to_entries[] | [.key, .value.version, .value.url, (.value.explicit // false | tostring), (.value.constraint // "")] | join($separator)' "${lockFile}")
}

loadInstalled()
{
  local name
  local version

  while IFS= read -r name; do
    if [[ -z "${name}" ]]; then
      continue
    fi
    version=$(extensionInstalledVersion "${basePath}" "${name}")
    if [[ "${version}" == "linked" ]] || [[ "${version}" == "local" ]] || [[ -z "${lockVersion[${name}]+x}" ]]; then
      fixedVersion["${name}"]="${version}"
      fixedPath["${name}"]="${installPath}/${name}"
      fixedScope["${name}"]="this"
    else
      installedVersion["${name}"]="${version}"
      selected["${name}"]="${version}"
      selectedUrl["${name}"]="${lockUrl[${name}]}"
    fi
  done < <(find "${installPath}" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n" | sort)

  # extensions installed for all users count as given for an installation of the user
  if [[ -n "${otherBasePath}" ]] && [[ -d "${otherBasePath}/extension" ]]; then
    while IFS= read -r name; do
      if [[ -n "${name}" ]] && [[ -z "${fixedVersion[${name}]+x}" ]] && [[ -z "${installedVersion[${name}]+x}" ]]; then
        fixedVersion["${name}"]=$(extensionInstalledVersion "${otherBasePath}" "${name}")
        fixedPath["${name}"]="${otherBasePath}/extension/${name}"
        fixedScope["${name}"]="shared"
      fi
    done < <(find "${otherBasePath}/extension" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n" | sort)
  fi
}

# --- systems ---

# prints the configuration file of the system in this directory (looked up like ads does) or of --file
projectFile()
{
  local directory

  if [[ -n "${optionFile}" ]]; then
    if [[ ! -f "${optionFile}" ]]; then
      fail "Could not find configuration at: ${optionFile}"
    fi
    realpath "${optionFile}"
    return 0
  fi

  for directory in . anodosys ads .. ../ads; do
    if [[ -f "${directory}/anodosys.json" ]]; then
      realpath "${directory}/anodosys.json"
      return 0
    fi
    if [[ -f "${directory}/ads.json" ]]; then
      realpath "${directory}/ads.json"
      return 0
    fi
  done
}

# loads the extensions that the registered systems and the system in this directory require, as lines of name,
# constraint, source and system separated by the unit separator
loadProjects()
{
  local systemName
  local fileName
  local currentFile
  local name
  local constraint
  local source
  declare -A seenFiles=()

  currentFile=$(projectFile)
  if [[ -n "${currentFile}" ]]; then
    systemName=$(jq -r '.global.systemName // empty' "${currentFile}" 2>/dev/null || true)
    while IFS="${separator}" read -r name constraint source; do
      if [[ -n "${name}" ]]; then
        projectLines+=( "${name}${separator}${constraint}${separator}${source}${separator}${systemName:-${currentFile}}" )
      fi
    done < <(extensionProjectRequirements "${currentFile}")
    seenFiles["${currentFile}"]=1
  fi

  if [[ ! -s "${anodosysUserPath}/systems.json" ]]; then
    return 0
  fi

  while IFS="${separator}" read -r systemName fileName; do
    if [[ -z "${fileName}" ]] || [[ ! -f "${fileName}" ]]; then
      continue
    fi
    fileName=$(realpath "${fileName}")
    if [[ -n "${seenFiles[${fileName}]}" ]]; then
      continue
    fi
    seenFiles["${fileName}"]=1
    while IFS="${separator}" read -r name constraint source; do
      if [[ -n "${name}" ]]; then
        projectLines+=( "${name}${separator}${constraint}${separator}${source}${separator}${systemName}" )
      fi
    done < <(extensionProjectRequirements "${fileName}")
  done < <(jq -r --arg separator "${separator}" 'to_entries[] | [.key, .value] | join($separator)' "${anodosysUserPath}/systems.json" 2>/dev/null || true)
}

# --- sources and registries ---

# sets lookupUrl to the git url of a source: a git url, a local path or a GitHub shorthand owner/repo, which is tried
# with https (public repositories) and then with ssh (private repositories)
resolveSource()
{
  local source="${1}"
  local candidate

  lookupUrl=
  if [[ -n "${resolvedSources[${source}]+x}" ]]; then
    lookupUrl="${resolvedSources[${source}]}"
    return 0
  fi

  if [[ "${source}" == /* ]] || [[ "${source}" == ./* ]] || [[ "${source}" == ../* ]]; then
    if [[ ! -d "${source}" ]]; then
      fail "Could not find directory: ${source}"
    fi
    lookupUrl=$(cd "${source}" && pwd)
  elif [[ "${source}" == *://* ]] || [[ "${source}" =~ ^[^/]+@[^/]+: ]]; then
    lookupUrl="${source}"
  elif [[ "${source}" =~ ${shorthandPattern} ]]; then
    for candidate in "https://github.com/${source}.git" "git@github.com:${source}.git"; do
      if git ls-remote --heads "${candidate}" > /dev/null 2>&1; then
        lookupUrl="${candidate}"
        break
      fi
    done
    if [[ -z "${lookupUrl}" ]]; then
      fail "Could not access repository: ${source} on GitHub with https or ssh"
    fi
  else
    fail "Invalid source: ${source}"
  fi

  resolvedSources["${source}"]="${lookupUrl}"
}

# prints the registries in the order they are searched
registryList()
{
  if [[ $(id -u) != 0 ]] && [[ -s "${anodosysUserPath}/registries.json" ]]; then
    jq -r '.[]' "${anodosysUserPath}/registries.json"
  fi
  if [[ -s "${sharedBasePath}/registries.json" ]]; then
    jq -r '.[]' "${sharedBasePath}/registries.json"
  fi
  if [[ -n "${defaultRegistry}" ]]; then
    echo "${defaultRegistry}"
  fi
}

# prints the registry.json of a registry, fetching a git registry into the cache first
registryFile()
{
  local registry="${1}"
  local cacheDirectory

  if [[ -f "${registry}" ]]; then
    echo "${registry}"
    return 0
  fi
  if [[ -d "${registry}" ]] && [[ -f "${registry}/registry.json" ]]; then
    echo "${registry}/registry.json"
    return 0
  fi

  cacheDirectory="${registryCachePath}/$(echo -n "${registry}" | md5sum | awk '{print $1}')"
  if [[ -d "${cacheDirectory}/.git" ]]; then
    if ! { git -C "${cacheDirectory}" fetch --quiet --depth 1 origin HEAD && git -C "${cacheDirectory}" reset --quiet --hard FETCH_HEAD; } > /dev/null 2>&1; then
      >&2 echo "Could not update registry: ${registry}, using the copy from before"
    fi
  else
    rm -rf "${cacheDirectory}"
    if ! git clone --quiet --depth 1 "${registry}" "${cacheDirectory}" > /dev/null 2>&1; then
      >&2 echo "Could not fetch registry: ${registry}"
      return 0
    fi
  fi

  if [[ -f "${cacheDirectory}/registry.json" ]]; then
    echo "${cacheDirectory}/registry.json"
  else
    >&2 echo "Registry: ${registry} has no registry.json"
  fi
}

loadRegistries()
{
  local registry
  local file
  local name
  local url
  local description

  if [[ "${registriesLoaded}" == 1 ]]; then
    return 0
  fi
  registriesLoaded=1

  while IFS= read -r registry; do
    if [[ -z "${registry}" ]]; then
      continue
    fi
    file=$(registryFile "${registry}")
    if [[ -z "${file}" ]]; then
      continue
    fi
    if ! jq empty "${file}" 2>/dev/null; then
      >&2 echo "Registry: ${registry} has an invalid registry.json"
      continue
    fi
    while IFS="${separator}" read -r name url description; do
      if [[ -z "${name}" ]] || [[ -z "${url}" ]]; then
        continue
      fi
      # the first registry that knows a name wins, so a private registry can replace a public extension
      if [[ -n "${registryUrl[${name}]+x}" ]]; then
        if [[ "${registryUrl[${name}]}" != "${url}" ]]; then
          >&2 echo "Extension: ${name} of registry: ${registry} is replaced by the one of registry: ${registrySource[${name}]}"
        fi
        continue
      fi
      registryUrl["${name}"]="${url}"
      registryDescription["${name}"]="${description}"
      registrySource["${name}"]="${registry}"
    done < <(jq -r --arg separator "${separator}" '.extensions // {} | to_entries[] | [.key, (if (.value | type) == "string" then .value else .value.url end), (if (.value | type) == "object" then .value.description // "" else "" end)] | join($separator)' "${file}")
  done < <(registryList)
}

# sets lookupUrl to the url of an extension: the requested one, the installed one, a registry or the sources of the
# extensions that require it
lookupExtension()
{
  local name="${1}"

  lookupUrl=
  if [[ -n "${requestUrl[${name}]}" ]]; then
    lookupUrl="${requestUrl[${name}]}"
    return 0
  fi
  if [[ -n "${lockUrl[${name}]}" ]]; then
    lookupUrl="${lockUrl[${name}]}"
    return 0
  fi
  loadRegistries
  if [[ -n "${registryUrl[${name}]}" ]]; then
    resolveSource "${registryUrl[${name}]}"
    return 0
  fi
  if [[ -n "${sourceHints[${name}]}" ]]; then
    resolveSource "${sourceHints[${name}]}"
    return 0
  fi
}

# --- versions ---

# loads the versions of an extension from the tags of its repository
loadRemoteVersions()
{
  local name="${1}"
  local url="${2}"
  local references
  local tag
  local versions=()

  if [[ -n "${remoteVersions[${name}]+x}" ]]; then
    return 0
  fi

  if ! references=$(git ls-remote --tags --refs "${url}" 2>&1); then
    fail "Could not read the versions of extension: ${name} from: ${url}: ${references}"
  fi

  while IFS= read -r tag; do
    tag="${tag##*refs/tags/}"
    if [[ "${tag}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      versions+=( "${tag#v}" )
      remoteTags["${name}/${tag#v}"]="${tag}"
    fi
  done <<< "${references}"

  remoteVersions["${name}"]="${versions[*]}"
}

# clones a version (a tag or the default branch) into a directory without its git data and prints the commit
cloneVersion()
{
  local url="${1}"
  local tag="${2}"
  local targetPath="${3}"
  local output
  local arguments=( clone --quiet --depth 1 )

  if [[ -n "${tag}" ]]; then
    arguments+=( --branch "${tag}" )
  fi

  rm -rf "${targetPath}"
  if ! output=$(git -c advice.detachedHead=false "${arguments[@]}" "${url}" "${targetPath}" 2>&1); then
    rm -rf "${targetPath}"
    fail "Could not clone: ${url}${tag:+ at: ${tag}}: ${output}"
  fi
  git -C "${targetPath}" rev-parse HEAD
  rm -rf "${targetPath}/.git"
}

# fetches a version of an extension into the store, unless it is there already; the default branch is fetched again
# when the extension is updated
fetchVersion()
{
  local name="${1}"
  local version="${2}"
  local url="${3}"
  local targetPath="${storePath}/${name}/${version}"
  local temporaryPath="${storePath}/${name}/.${version}.$$"
  local commit
  local tag=

  # copies of the release before, which kept a clone of the repository directly in this directory
  if [[ -d "${storePath}/${name}/.git" ]]; then
    rm -rf "${storePath:?}/${name}"
  fi

  if [[ -d "${targetPath}" ]] && [[ -f "${targetPath}.commit" ]]; then
    if [[ "${version}" != "dev" ]] || [[ -n "${refetched[${name}]}" ]] || { [[ "${upgradeAll}" != 1 ]] && [[ -z "${upgrade[${name}]}" ]]; }; then
      return 0
    fi
  fi

  mkdir -p "${storePath}/${name}"
  if [[ "${version}" != "dev" ]]; then
    tag="${remoteTags[${name}/${version}]:-${version}}"
  fi
  echo "Fetching extension: ${name} ${version} from: ${url}"
  commit=$(cloneVersion "${url}" "${tag}" "${temporaryPath}")
  rm -rf "${targetPath}"
  mv "${temporaryPath}" "${targetPath}"
  echo "${commit}" > "${targetPath}.commit"
  if [[ "${version}" == "dev" ]]; then
    refetched["${name}"]=1
  fi
}

# prints the path of the extension.json of a selected or given extension
manifestPath()
{
  local name="${1}"

  if [[ -n "${selected[${name}]}" ]]; then
    echo -n "${storePath}/${name}/${selected[${name}]}/extension.json"
  elif [[ -n "${fixedPath[${name}]}" ]]; then
    echo -n "${fixedPath[${name}]}/extension.json"
  fi
}

# describes a version for messages: "1.2.0", "dev" or "linked"
describeVersion()
{
  local name="${1}"

  if [[ -n "${selected[${name}]}" ]]; then
    echo -n "${selected[${name}]}"
  else
    echo -n "${fixedVersion[${name}]}"
  fi
}

# collects the extensions that are needed, starting with the requested ones and following the requirements of the
# selected versions, and the constraints every requiring extension puts on them
collectRequirements()
{
  local queue=()
  local name
  local manifestFile
  local requiredName
  local requiredConstraint
  local source
  local line
  local systemLabel

  constraints=()
  needed=()

  # the roots: requested extensions, the ones requested before, and linked or local ones of this installation
  for name in "${!requested[@]}" "${!lockExplicit[@]}" "${!fixedVersion[@]}"; do
    if [[ -n "${removing[${name}]}" ]] || [[ -n "${needed[${name}]}" ]]; then
      continue
    fi
    if [[ -z "${requested[${name}]}" ]]; then
      if [[ -n "${fixedVersion[${name}]+x}" ]]; then
        if [[ "${fixedScope[${name}]}" != "this" ]]; then
          continue
        fi
      elif [[ "${lockExplicit[${name}]}" != "true" ]] || [[ -z "${installedVersion[${name}]+x}" ]]; then
        continue
      fi
    fi
    needed["${name}"]=1
    queue+=( "${name}" )
    if [[ -n "${requestConstraint[${name}]}" ]]; then
      constraints["${name}"]+="${requestConstraint[${name}]}"$'\t'"requested"$'\n'
    elif [[ -n "${lockConstraint[${name}]}" ]]; then
      constraints["${name}"]+="${lockConstraint[${name}]}"$'\t'"requested"$'\n'
    fi
  done

  # the systems keep their extensions to their constraints, without installing them
  for line in "${projectLines[@]}"; do
    IFS="${separator}" read -r name requiredConstraint source systemLabel <<< "${line}"
    constraints["${name}"]+="${requiredConstraint:-*}"$'\t'"system ${systemLabel}"$'\n'
    if [[ -n "${source}" ]] && [[ -z "${sourceHints[${name}]}" ]]; then
      sourceHints["${name}"]="${source}"
    fi
  done

  while [[ "${#queue[@]}" -gt 0 ]]; do
    name="${queue[0]}"
    queue=( "${queue[@]:1}" )
    manifestFile=$(manifestPath "${name}")
    if [[ -z "${manifestFile}" ]] || [[ ! -f "${manifestFile}" ]]; then
      continue
    fi
    if ! jq empty "${manifestFile}" 2>/dev/null; then
      fail "Extension: ${name} has an invalid extension.json"
    fi
    while IFS="${separator}" read -r requiredName requiredConstraint source; do
      if [[ -z "${requiredName}" ]]; then
        continue
      fi
      if [[ ! "${requiredName}" =~ ${namePattern} ]]; then
        fail "Extension: ${name} requires an extension with an invalid name: ${requiredName}"
      fi
      constraints["${requiredName}"]+="${requiredConstraint:-*}"$'\t'"${name} $(describeVersion "${name}")"$'\n'
      if [[ -n "${source}" ]] && [[ -z "${sourceHints[${requiredName}]}" ]]; then
        sourceHints["${requiredName}"]="${source}"
      fi
      if [[ -z "${needed[${requiredName}]}" ]] && [[ -z "${removing[${requiredName}]}" || "${force}" != 1 ]]; then
        needed["${requiredName}"]=1
        queue+=( "${requiredName}" )
      fi
    done < <(jq -r --arg separator "${separator}" '(.sources // {}) as $sources | .requires // {} | to_entries[] | [.key, .value, ($sources[.key] // "")] | join($separator)' "${manifestFile}")
  done
}

# prints the constraints of an extension, one per line, without the requiring extensions
constraintList()
{
  local name="${1}"

  printf '%s' "${constraints[${name}]}" | cut -f1
}

# describes the constraints of an extension for messages
constraintDescription()
{
  local name="${1}"

  printf '%s' "${constraints[${name}]}" | awk -F'\t' 'NF { printf "  %s (%s)\n", $1, $2 }'
}

# sets chosenVersion to the version of an extension that matches all constraints: the selected one, unless the
# extension is updated, otherwise the highest; the default branch when it is requested or when there are no tags
chooseVersion()
{
  local name="${1}"
  local current="${selected[${name}]}"
  local list
  local constraint
  local matches
  local versions

  chosenVersion=
  list=$(constraintList "${name}")

  if [[ -n "${current}" ]] && [[ "${upgradeAll}" != 1 ]] && [[ -z "${upgrade[${name}]}" ]]; then
    matches=1
    while IFS= read -r constraint; do
      if [[ -n "${constraint}" ]] && [[ "${constraint}" != "*" ]] && [[ "${current}" != "dev" ]] && [[ $(versionSatisfies "${current}" "${constraint}") != 1 ]]; then
        matches=0
      fi
      if [[ "${constraint}" == "dev" ]] && [[ "${current}" != "dev" ]]; then
        matches=0
      fi
    done <<< "${list}"
    if [[ "${matches}" == 1 ]]; then
      chosenVersion="${current}"
      return 0
    fi
  fi

  if grep -qx "dev" <<< "${list}"; then
    chosenVersion="dev"
    return 0
  fi

  loadRemoteVersions "${name}" "${selectedUrl[${name}]}"
  read -r -a versions <<< "${remoteVersions[${name}]}"

  if [[ "${#versions[@]}" -eq 0 ]]; then
    >&2 echo "Extension: ${name} has no versions (tags like 1.0.0), using its default branch"
    chosenVersion="dev"
    return 0
  fi

  chosenVersion=$(versionHighest "${list}" "${versions[@]}")
  if [[ -z "${chosenVersion}" ]]; then
    >&2 echo "No version of extension: ${name} matches all constraints:"
    >&2 constraintDescription "${name}"
    >&2 echo "Available versions: $(printf '%s\n' "${versions[@]}" | sort -V | tr '\n' ' ')"
    exit 1
  fi
}

# selects a version of every needed extension until nothing changes any more
resolve()
{
  local iteration
  local changed
  local name
  local requiredBy

  for (( iteration=1; iteration <= 50; iteration++ )); do
    collectRequirements
    changed=0

    for name in $(printf '%s\n' "${!needed[@]}" | sort); do
      if [[ -n "${fixedVersion[${name}]+x}" ]] && [[ -z "${replacing[${name}]}" ]]; then
        continue
      fi
      if [[ -n "${removing[${name}]}" ]]; then
        continue
      fi
      if [[ -z "${selectedUrl[${name}]}" ]]; then
        lookupExtension "${name}"
        if [[ -z "${lookupUrl}" ]]; then
          requiredBy=$(printf '%s' "${constraints[${name}]}" | cut -f2 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
          fail "Could not find extension: ${name}${requiredBy:+ (required by: ${requiredBy})} in any registry, add a registry with: ads extension registry add <url>, or install it from its repository with: ads extension install <url>"
        fi
        selectedUrl["${name}"]="${lookupUrl}"
      fi
      chooseVersion "${name}"
      if [[ "${selected[${name}]}" != "${chosenVersion}" ]] || [[ ! -d "${storePath}/${name}/${chosenVersion}" ]]; then
        selected["${name}"]="${chosenVersion}"
        fetchVersion "${name}" "${chosenVersion}" "${selectedUrl[${name}]}"
        changed=1
      elif [[ "${chosenVersion}" == "dev" ]] && [[ -z "${refetched[${name}]}" ]] && { [[ "${upgradeAll}" == 1 ]] || [[ -n "${upgrade[${name}]}" ]]; }; then
        fetchVersion "${name}" "${chosenVersion}" "${selectedUrl[${name}]}"
        changed=1
      fi
    done

    # extensions that nothing needs any more, for example dependencies of a removed extension
    for name in "${!selected[@]}"; do
      if [[ -z "${needed[${name}]}" ]]; then
        unset 'selected[${name}]'
        changed=1
      fi
    done

    if [[ "${changed}" == 0 ]]; then
      return 0
    fi
  done

  fail "Could not resolve the versions of the extensions, the requirements change with every version"
}

# checks what cannot be chosen: the Anodosys version and extensions that are linked or installed for all users
verifyResolution()
{
  local name
  local version
  local constraint
  local requiredBy
  local manifestFile
  local anodosysConstraint
  local currentVersion
  local problems=0

  currentVersion=$(anodosysCurrentVersion "${anodosysPath}")

  for name in "${!selected[@]}"; do
    manifestFile=$(manifestPath "${name}")
    if [[ -f "${manifestFile}" ]]; then
      anodosysConstraint=$(jq -r '.anodosys // empty' "${manifestFile}")
      if [[ -n "${anodosysConstraint}" ]] && [[ -n "${currentVersion}" ]] && [[ $(versionSatisfies "${currentVersion}" "${anodosysConstraint}") != 1 ]]; then
        >&2 echo "Extension: ${name} ${selected[${name}]} requires Anodosys ${anodosysConstraint}, installed is: ${currentVersion}, run: ads update"
        problems=1
      fi
    fi
  done

  for name in "${!needed[@]}"; do
    if [[ -n "${selected[${name}]}" ]]; then
      version="${selected[${name}]}"
    elif [[ -n "${fixedVersion[${name}]+x}" ]] && [[ -z "${removing[${name}]}" ]]; then
      version="${fixedVersion[${name}]}"
    else
      requiredBy=$(printf '%s' "${constraints[${name}]}" | cut -f2 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
      >&2 echo "Extension: ${name} is still required by: ${requiredBy}"
      problems=1
      continue
    fi
    while IFS=$'\t' read -r constraint requiredBy; do
      if [[ -z "${constraint}" ]] || [[ "${constraint}" == "*" ]]; then
        continue
      fi
      if [[ "${version}" == "linked" ]] || [[ "${version}" == "local" ]] || { [[ "${version}" == "dev" ]] && [[ "${constraint}" != "dev" ]]; }; then
        >&2 echo "Extension: ${name} is ${version}, its version is not checked against: ${constraint} of: ${requiredBy}"
        continue
      fi
      if [[ $(versionSatisfies "${version}" "${constraint}") != 1 ]]; then
        >&2 echo "Extension: ${name} ${version}${fixedScope[${name}]:+ (installed for all users)} does not match: ${constraint} of: ${requiredBy}"
        problems=1
      fi
    done <<< "${constraints[${name}]}"
  done

  if [[ "${problems}" == 1 ]]; then
    if [[ "${force}" == 1 ]]; then
      >&2 echo "Continuing because of --force"
    else
      exit 1
    fi
  fi
}

# links the selected versions, removes what is no longer selected and writes the lock file
apply()
{
  local name
  local version
  local content='{}'
  local explicit
  local constraint
  local commit
  local storedVersion

  for name in $(printf '%s\n' "${!removing[@]}" | sort); do
    if [[ -n "${fixedVersion[${name}]+x}" ]] && [[ "${fixedScope[${name}]}" == "this" ]]; then
      echo "Removing extension: ${name} (${fixedVersion[${name}]})" | sed $'s,.*,\e[1;36m&\e[m,'
      if [[ -L "${installPath}/${name}" ]]; then
        rm "${installPath:?}/${name}"
      else
        rm -rf "${installPath:?}/${name}"
      fi
    fi
  done

  for name in $(printf '%s\n' "${!installedVersion[@]}" | sort); do
    if [[ -z "${selected[${name}]}" ]]; then
      echo "Removing extension: ${name} ${installedVersion[${name}]}" | sed $'s,.*,\e[1;36m&\e[m,'
      rm -f "${installPath:?}/${name}"
      rm -rf "${storePath:?}/${name}"
    fi
  done

  for name in $(printf '%s\n' "${!selected[@]}" | sort); do
    version="${selected[${name}]}"
    if [[ -n "${replacing[${name}]}" ]] && [[ -e "${installPath}/${name}" || -L "${installPath}/${name}" ]] && [[ -n "${fixedVersion[${name}]+x}" ]]; then
      echo "Replacing extension: ${name} (${fixedVersion[${name}]})"
      if [[ -L "${installPath}/${name}" ]]; then
        rm "${installPath:?}/${name}"
      else
        rm -rf "${installPath:?}/${name}"
      fi
    fi
    if [[ -z "${installedVersion[${name}]}" ]]; then
      echo "Installed extension: ${name} ${version}" | sed $'s,.*,\e[0;32m&\e[m,'
    elif [[ "${installedVersion[${name}]}" != "${version}" ]]; then
      echo "Updated extension: ${name} ${installedVersion[${name}]} -> ${version}" | sed $'s,.*,\e[0;32m&\e[m,'
    elif [[ -n "${refetched[${name}]}" ]]; then
      echo "Updated extension: ${name} ${version} to commit: $(head -c 12 "${storePath}/${name}/${version}.commit")" | sed $'s,.*,\e[0;32m&\e[m,'
    elif [[ -n "${requested[${name}]}" ]]; then
      echo "Extension: ${name} ${version} is installed already"
    fi
    ln -sfn "${storePath}/${name}/${version}" "${installPath}/${name}"

    # older versions of the extension are not needed any more
    while IFS= read -r storedVersion; do
      if [[ -n "${storedVersion}" ]] && [[ "${storedVersion}" != "${version}" ]]; then
        rm -rf "${storePath:?}/${name}/${storedVersion}" "${storePath:?}/${name}/${storedVersion}.commit"
      fi
    done < <(find "${storePath}/${name}" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf "%f\n")

    if [[ -n "${requested[${name}]}" ]] || [[ "${lockExplicit[${name}]}" == "true" ]]; then
      explicit=true
    else
      explicit=false
    fi
    constraint="${requestConstraint[${name}]:-${lockConstraint[${name}]}}"
    commit=$(cat "${storePath}/${name}/${version}.commit" 2>/dev/null || true)
    content=$(jq --arg name "${name}" --arg version "${version}" --arg url "${selectedUrl[${name}]}" \
      --arg commit "${commit}" --argjson explicit "${explicit}" --arg constraint "${constraint}" \
      '.[$name] = ({version: $version, url: $url, commit: $commit, explicit: $explicit} + (if $constraint == "" then {} else {constraint: $constraint} end))' <<< "${content}")
  done

  echo "${content}" > "${lockFile}.$$.tmp"
  mv "${lockFile}.$$.tmp" "${lockFile}"
}

# reports problems of all installed extensions after a change
report()
{
  local problems

  problems=$(extensionProblems "$(anodosysCurrentVersion "${anodosysPath}")" "${sharedBasePath}" ${otherBasePath:+"${anodosysUserPath}"})
  if [[ -n "${problems}" ]]; then
    >&2 echo "${problems}"
  fi
}

# parses <source>[@<constraint>] into specSource and specConstraint; a git url like git@host:path has no constraint
parseSpec()
{
  local spec="${1}"

  specSource="${spec}"
  specConstraint=
  if [[ "${spec}" =~ ^(.+)@([^@:/]+)$ ]]; then
    specSource="${BASH_REMATCH[1]}"
    specConstraint="${BASH_REMATCH[2]}"
  fi
}

# requests an extension given by url, path or shorthand: its name comes from --name or its extension.json, which is
# read from the newest version that matches the constraint
requestSource()
{
  local source="${1}"
  local constraint="${2}"
  local name="${optionName}"
  local url
  local versions
  local version
  local probePath="${storePath}/.probe.$$"
  local commit

  resolveSource "${source}"
  url="${lookupUrl}"

  loadRemoteVersions ".probe" "${url}"
  read -r -a versions <<< "${remoteVersions[.probe]}"
  if [[ "${constraint}" == "dev" ]] || [[ "${#versions[@]}" -eq 0 ]]; then
    version="dev"
  else
    version=$(versionHighest "${constraint:-*}" "${versions[@]}")
    if [[ -z "${version}" ]]; then
      fail "No version of: ${source} matches: ${constraint}, available versions: ${versions[*]}"
    fi
  fi

  if [[ -z "${name}" ]]; then
    echo "Fetching extension from: ${url} (${version})"
    commit=$(cloneVersion "${url}" "$([[ "${version}" != "dev" ]] && echo "${remoteTags[.probe/${version}]}")" "${probePath}")
    if [[ -f "${probePath}/extension.json" ]]; then
      name=$(jq -r '.name // empty' "${probePath}/extension.json" 2>/dev/null || true)
    fi
    if [[ -z "${name}" ]]; then
      rm -rf "${probePath}"
      fail "The extension.json of: ${source} names no extension, please add: --name <name>"
    fi
    if [[ ! "${name}" =~ ${namePattern} ]]; then
      rm -rf "${probePath}"
      fail "Invalid extension name: ${name} in the extension.json of: ${source}"
    fi
    mkdir -p "${storePath}/${name}"
    rm -rf "${storePath:?}/${name}/${version}"
    mv "${probePath}" "${storePath}/${name}/${version}"
    echo "${commit}" > "${storePath}/${name}/${version}.commit"
    if [[ "${version}" == "dev" ]]; then
      refetched["${name}"]=1
    fi
  fi

  if [[ ! "${name}" =~ ${namePattern} ]]; then
    fail "Invalid extension name: ${name}"
  fi

  remoteVersions["${name}"]="${remoteVersions[.probe]}"
  for version in "${versions[@]}"; do
    remoteTags["${name}/${version}"]="${remoteTags[.probe/${version}]}"
  done
  unset 'remoteVersions[.probe]'

  requestName="${name}"
  requestUrl["${name}"]="${url}"
  if [[ -n "${lockUrl[${name}]}" ]] && [[ "${lockUrl[${name}]}" != "${url}" ]]; then
    echo "Extension: ${name} is now installed from: ${url} instead of: ${lockUrl[${name}]}"
    unset 'selected[${name}]'
  fi
  selectedUrl["${name}"]="${url}"
}

# prepares a request for an extension: an existing linked or local extension of the same name is only replaced with --force
requestExtension()
{
  local name="${1}"
  local constraint="${2}"

  if [[ -n "${fixedVersion[${name}]+x}" ]]; then
    if [[ "${fixedScope[${name}]}" != "this" ]]; then
      fail "Extension: ${name} is installed for all users in: ${fixedPath[${name}]}, change it as root"
    fi
    if [[ "${force}" != 1 ]]; then
      fail "Extension: ${name} exists as ${fixedVersion[${name}]} extension in: ${fixedPath[${name}]}, replace it with: --force"
    fi
    replacing["${name}"]=1
  fi

  requested["${name}"]=1
  if [[ -n "${constraint}" ]]; then
    requestConstraint["${name}"]="${constraint}"
    # a new constraint may need another version than the installed one
    if [[ -n "${selected[${name}]}" ]] && [[ "${constraint}" != "dev" ]] && [[ $(versionSatisfies "${selected[${name}]}" "${constraint}") != 1 ]]; then
      upgrade["${name}"]=1
    fi
    if [[ "${constraint}" == "dev" ]] && [[ "${selected[${name}]}" != "dev" ]]; then
      upgrade["${name}"]=1
    fi
  fi
}

lockChanges()
{
  # one change at a time, several systems may install extensions at the same time
  exec 9> "${lockFile}.lock"
  flock 9
  loadLock
  loadInstalled
  loadProjects
}

# --- actions ---

case "${action}" in
  install|add)
    # add <name> git <url> of the releases before
    if [[ "${action}" == "add" ]] && [[ "${2}" == "git" ]] && [[ -n "${3}" ]]; then
      >&2 echo "\"ads extension add <name> git <url>\" is deprecated, use: ads extension install <url> --name <name>"
      optionName="${1}"
      set -- "${3}"
    fi
    if [[ -n "${optionName}" ]] && [[ "$#" -gt 1 ]]; then
      fail "--name can only be used with one extension"
    fi
    lockChanges
    # without arguments: the extensions of the system in this directory, their constraints come from loadProjects
    if [[ "$#" -eq 0 ]]; then
      systemFile=$(projectFile)
      if [[ -z "${systemFile}" ]]; then
        >&2 echo "No extension defined and no anodosys.json or ads.json found in: ${PWD}"
        usage
        exit 1
      fi
      systemRequirements=$(extensionProjectRequirements "${systemFile}")
      if [[ -z "${systemRequirements}" ]]; then
        fail "The configuration: ${systemFile} requires no extensions, add them as: \"extensions\": { \"<name>\": \"<constraint>\" }"
      fi
      echo "Installing the extensions of: ${systemFile}"
      while IFS="${separator}" read -r name constraint source; do
        if [[ -z "${name}" ]]; then
          continue
        fi
        # linked and local extensions are used as they are
        if [[ -n "${fixedVersion[${name}]+x}" ]] && [[ "${force}" != 1 ]]; then
          echo "Extension: ${name} is used as it is (${fixedVersion[${name}]}) from: ${fixedPath[${name}]}"
          continue
        fi
        requestExtension "${name}" ""
      done <<< "${systemRequirements}"
    fi
    for spec in "$@"; do
      parseSpec "${spec}"
      if [[ "${specSource}" =~ ${namePattern} ]] && [[ -z "${optionName}" ]]; then
        requestExtension "${specSource}" "${specConstraint}"
      else
        requestSource "${specSource}" "${specConstraint}"
        requestExtension "${requestName}" "${specConstraint}"
      fi
    done
    resolve
    verifyResolution
    apply
    report
    ;;

  update|reset)
    if [[ "${action}" == "reset" ]]; then
      >&2 echo "\"ads extension reset\" is deprecated, installed versions are not changed locally, updating instead"
    fi
    lockChanges
    if [[ "$#" -eq 0 ]]; then
      upgradeAll=1
    fi
    for name in "$@"; do
      if [[ -n "${fixedVersion[${name}]+x}" ]]; then
        if [[ "${fixedVersion[${name}]}" == "linked" ]]; then
          fail "Extension: ${name} is linked to: $(readlink -f "${fixedPath[${name}]}"), update its checkout instead"
        fi
        fail "Extension: ${name} was not installed with \"ads extension install\", install it again with: ads extension install ${name} --force"
      fi
      if [[ -z "${installedVersion[${name}]+x}" ]]; then
        fail "Extension: ${name} is not installed"
      fi
      upgrade["${name}"]=1
    done
    resolve
    verifyResolution
    apply
    report
    ;;

  remove)
    if [[ "$#" -eq 0 ]]; then
      >&2 echo "No extension defined!"
      usage
      exit 1
    fi
    lockChanges
    for name in "$@"; do
      if [[ -z "${installedVersion[${name}]+x}" ]] && { [[ -z "${fixedVersion[${name}]+x}" ]] || [[ "${fixedScope[${name}]}" != "this" ]]; }; then
        fail "Extension: ${name} is not installed in: ${installPath}"
      fi
      removing["${name}"]=1
      unset 'selected[${name}]'
    done
    resolve
    verifyResolution
    apply
    report
    ;;

  link)
    if [[ -z "${1}" ]] || [[ ! -d "${1}" ]]; then
      fail "No directory to link defined!"
    fi
    lockChanges
    linkPath=$(cd "${1}" && pwd)
    name="${optionName}"
    if [[ -z "${name}" ]] && [[ -f "${linkPath}/extension.json" ]]; then
      name=$(jq -r '.name // empty' "${linkPath}/extension.json")
    fi
    if [[ -z "${name}" ]]; then
      name=$(basename "${linkPath}")
    fi
    if [[ ! "${name}" =~ ${namePattern} ]]; then
      fail "Invalid extension name: ${name}, please add: --name <name>"
    fi
    if [[ -e "${installPath}/${name}" ]] || [[ -L "${installPath}/${name}" ]]; then
      if [[ "${force}" != 1 ]]; then
        fail "Extension: ${name} exists already in: ${installPath}/${name}, replace it with: --force"
      fi
      if [[ -L "${installPath}/${name}" ]]; then
        rm "${installPath:?}/${name}"
      else
        rm -rf "${installPath:?}/${name}"
      fi
      if [[ -n "${installedVersion[${name}]+x}" ]]; then
        rm -rf "${storePath:?}/${name}"
        unset 'installedVersion[${name}]' 'selected[${name}]' 'lockExplicit[${name}]'
      fi
    fi
    ln -s "${linkPath}" "${installPath}/${name}"
    echo "Linked extension: ${name} to: ${linkPath}" | sed $'s,.*,\e[0;32m&\e[m,'
    fixedVersion["${name}"]="linked"
    fixedPath["${name}"]="${installPath}/${name}"
    fixedScope["${name}"]="this"
    # installs what the checkout requires
    resolve
    verifyResolution
    apply
    report
    ;;

  unlink)
    name="${1}"
    if [[ -z "${name}" ]]; then
      fail "No extension defined!"
    fi
    lockChanges
    if [[ "${fixedVersion[${name}]}" != "linked" ]] || [[ "${fixedScope[${name}]}" != "this" ]]; then
      fail "Extension: ${name} is not linked in: ${installPath}"
    fi
    removing["${name}"]=1
    resolve
    verifyResolution
    apply
    report
    ;;

  list)
    loadLock
    printf '%-24s %-10s %-7s %s\n' "NAME" "VERSION" "SCOPE" "SOURCE"
    listScope()
    {
      local scopeBasePath="${1}"
      local scope="${2}"
      local name
      local version
      local source

      if [[ ! -d "${scopeBasePath}/extension" ]]; then
        return 0
      fi
      while IFS= read -r name; do
        if [[ -z "${name}" ]]; then
          continue
        fi
        version=$(extensionInstalledVersion "${scopeBasePath}" "${name}")
        if [[ "${version}" == "linked" ]]; then
          source=$(readlink -f "${scopeBasePath}/extension/${name}")
        elif [[ "${version}" == "local" ]]; then
          source="${scopeBasePath}/extension/${name}"
        else
          source=$(jq -r --arg name "${name}" '.[$name].url // empty' "${scopeBasePath}/extensions.json")
          if [[ $(jq -r --arg name "${name}" '.[$name].explicit // false' "${scopeBasePath}/extensions.json") != "true" ]]; then
            source="${source} (dependency)"
          fi
        fi
        printf '%-24s %-10s %-7s %s\n' "${name}" "${version}" "${scope}" "${source}"
      done < <(find "${scopeBasePath}/extension" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n" | sort)
    }
    if [[ $(id -u) != 0 ]]; then
      listScope "${anodosysUserPath}" "user"
    fi
    listScope "${sharedBasePath}" "shared"
    ;;

  outdated)
    loadLock
    loadInstalled
    loadProjects
    collectRequirements
    printf '%-24s %-10s %-10s %s\n' "NAME" "INSTALLED" "MATCHING" "LATEST"
    for name in $(printf '%s\n' "${!installedVersion[@]}" | sort); do
      loadRemoteVersions "${name}" "${selectedUrl[${name}]}"
      read -r -a versions <<< "${remoteVersions[${name}]}"
      if [[ "${#versions[@]}" -eq 0 ]]; then
        continue
      fi
      latest=$(versionHighest "*" "${versions[@]}")
      matching=$(versionHighest "$(constraintList "${name}")" "${versions[@]}")
      if [[ "${installedVersion[${name}]}" == "dev" ]] || [[ "${latest}" != "${installedVersion[${name}]}" ]]; then
        printf '%-24s %-10s %-10s %s\n' "${name}" "${installedVersion[${name}]}" "${matching:--}" "${latest}"
      fi
    done
    ;;

  search)
    loadLock
    loadInstalled
    loadRegistries
    text="${1}"
    for name in $(printf '%s\n' "${!registryUrl[@]}" | sort); do
      if [[ -n "${text}" ]] && [[ "${name}" != *"${text}"* ]] && [[ "${registryDescription[${name}]}" != *"${text}"* ]]; then
        continue
      fi
      state=
      if [[ -n "${installedVersion[${name}]}" ]]; then
        state=" [installed ${installedVersion[${name}]}]"
      elif [[ -n "${fixedVersion[${name}]+x}" ]]; then
        state=" [${fixedVersion[${name}]}]"
      fi
      printf '%-24s %s%s\n' "${name}" "${registryDescription[${name}]}" "${state}"
    done
    ;;

  check)
    problems=$(extensionProblems "$(anodosysCurrentVersion "${anodosysPath}")" "${sharedBasePath}" ${otherBasePath:+"${anodosysUserPath}"})
    # the system in this directory and the registered systems
    checkBasePaths=( "${basePath}" ${otherBasePath:+"${otherBasePath}"} )
    declare -A checkedFiles=()
    systemFile=$(projectFile)
    if [[ -n "${systemFile}" ]]; then
      checkedFiles["${systemFile}"]=1
      systemProblems=$(extensionProjectProblems "${systemFile}" "$(jq -r '.global.systemName // empty' "${systemFile}" 2>/dev/null || true)" "${checkBasePaths[@]}")
      problems="${problems}${problems:+${systemProblems:+$'\n'}}${systemProblems}"
    fi
    if [[ -s "${anodosysUserPath}/systems.json" ]]; then
      while IFS="${separator}" read -r systemName systemFile; do
        if [[ -z "${systemFile}" ]] || [[ ! -f "${systemFile}" ]]; then
          continue
        fi
        systemFile=$(realpath "${systemFile}")
        if [[ -n "${checkedFiles[${systemFile}]}" ]]; then
          continue
        fi
        checkedFiles["${systemFile}"]=1
        systemProblems=$(extensionProjectProblems "${systemFile}" "${systemName}" "${checkBasePaths[@]}")
        problems="${problems}${problems:+${systemProblems:+$'\n'}}${systemProblems}"
      done < <(jq -r --arg separator "${separator}" 'to_entries[] | [.key, .value] | join($separator)' "${anodosysUserPath}/systems.json" 2>/dev/null || true)
    fi
    if [[ -n "${problems}" ]]; then
      >&2 echo "${problems}"
      exit 1
    fi
    echo "All extensions have what they require" | sed $'s,.*,\e[0;32m&\e[m,'
    ;;

  registry)
    registryAction="${1}"
    registry="${2}"
    case "${registryAction}" in
      ""|list)
        registryList
        ;;
      add|remove)
        if [[ -z "${registry}" ]]; then
          fail "No registry defined!"
        fi
        if [[ -d "${registry}" ]] || [[ -f "${registry}" ]]; then
          registry=$(realpath "${registry}")
        elif [[ "${registry}" =~ ${shorthandPattern} ]]; then
          resolveSource "${registry}"
          registry="${lookupUrl}"
        fi
        exec 9> "${registriesFile}.lock"
        flock 9
        if [[ ! -s "${registriesFile}" ]]; then
          echo '[]' > "${registriesFile}"
        fi
        if [[ "${registryAction}" == "add" ]]; then
          jq --arg registry "${registry}" 'map(select(. != $registry)) + [$registry]' "${registriesFile}" > "${registriesFile}.$$.tmp"
          echo "Added registry: ${registry}"
        else
          jq --arg registry "${registry}" 'map(select(. != $registry))' "${registriesFile}" > "${registriesFile}.$$.tmp"
          echo "Removed registry: ${registry}"
        fi
        mv "${registriesFile}.$$.tmp" "${registriesFile}"
        ;;
      *)
        fail "Invalid registry action: ${registryAction}, use: list, add or remove"
        ;;
    esac
    ;;

  *)
    >&2 echo "Invalid action: ${action} defined!"
    usage
    exit 1
    ;;
esac
