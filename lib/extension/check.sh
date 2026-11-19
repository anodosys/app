#!/bin/bash -e

# Installed extensions live in <base>/extension/<name>: a link into <base>/var/extension/<name>/<version> for an
# extension installed by "ads extension install" (recorded in <base>/extensions.json), any other link (an extension
# linked from a checkout) or a plain directory (installed by an older release). <base> is the shared directory of the
# installed release (or the checkout) and the user directory (~/.anodosys).

# prints the version of an installed extension: its version, "dev" for the default branch, "linked" or "local"
extensionInstalledVersion()
{
  local basePath="${1}"
  local name="${2}"
  local extensionPath="${basePath}/extension/${name}"
  local target
  local version

  if [[ -L "${extensionPath}" ]]; then
    target=$(readlink -f "${extensionPath}")
    if [[ "${target}" == "$(readlink -f "${basePath}/var/extension")/${name}/"* ]] && [[ -f "${basePath}/extensions.json" ]]; then
      version=$(jq -r --arg name "${name}" '.[$name].version // empty' "${basePath}/extensions.json" 2>/dev/null || true)
      if [[ -n "${version}" ]] && [[ "${target}" == */"${name}/${version}" ]]; then
        echo -n "${version}"
        return 0
      fi
    fi
    echo -n "linked"
    return 0
  fi

  if [[ -d "${extensionPath}" ]]; then
    echo -n "local"
  fi
}

# shellcheck disable=SC2034
typeset -fx extensionInstalledVersion

# prints one line per problem of the installed extensions: a missing or unsuitable required extension or Anodosys
# version, with the command that solves it; prints nothing when everything fits
extensionProblems()
{
  local currentVersion="${1}"
  shift
  local basePaths=( "$@" )
  local basePath
  local name
  local manifestFile
  local requirement
  local requiredName
  local requiredConstraint
  local requiredVersion
  local anodosysConstraint
  declare -A installedVersions=()
  declare -A installedPaths=()

  for basePath in "${basePaths[@]}"; do
    if [[ -d "${basePath}/extension" ]]; then
      while IFS= read -r name; do
        if [[ -n "${name}" ]]; then
          installedVersions["${name}"]=$(extensionInstalledVersion "${basePath}" "${name}")
          installedPaths["${name}"]="${basePath}/extension/${name}"
        fi
      done < <(find "${basePath}/extension" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n" | sort)
    fi
  done

  for name in $(printf '%s\n' "${!installedPaths[@]}" | sort); do
    manifestFile="${installedPaths[${name}]}/extension.json"
    if [[ ! -f "${manifestFile}" ]]; then
      continue
    fi

    if ! jq empty "${manifestFile}" 2>/dev/null; then
      echo "Extension: ${name} has an invalid extension.json"
      continue
    fi

    anodosysConstraint=$(jq -r '.anodosys // empty' "${manifestFile}")
    if [[ -n "${anodosysConstraint}" ]] && [[ -n "${currentVersion}" ]] && [[ $(versionSatisfies "${currentVersion}" "${anodosysConstraint}") != 1 ]]; then
      echo "Extension: ${name} requires Anodosys ${anodosysConstraint}, installed is: ${currentVersion}, run: ads update"
    fi

    while IFS= read -r requirement; do
      if [[ -z "${requirement}" ]]; then
        continue
      fi
      requiredName="${requirement%%$'\t'*}"
      requiredConstraint="${requirement#*$'\t'}"
      if [[ -z "${installedVersions[${requiredName}]+x}" ]]; then
        echo "Extension: ${name} requires extension: ${requiredName} ${requiredConstraint}, which is not installed, run: ads extension install ${requiredName}"
        continue
      fi
      requiredVersion="${installedVersions[${requiredName}]}"
      # linked and local extensions have no known version, the default branch matches only "dev"
      if [[ "${requiredVersion}" == "linked" ]] || [[ "${requiredVersion}" == "local" ]] || [[ "${requiredVersion}" == "dev" ]]; then
        continue
      fi
      if [[ $(versionSatisfies "${requiredVersion}" "${requiredConstraint}") != 1 ]]; then
        echo "Extension: ${name} requires extension: ${requiredName} ${requiredConstraint}, installed is: ${requiredVersion}, run: ads extension update ${requiredName}"
      fi
    done < <(jq -r '.requires // {} | to_entries[] | "\(.key)\t\(.value)"' "${manifestFile}")
  done
}

# shellcheck disable=SC2034
typeset -fx extensionProblems

# prints the extensions a system configuration requires, one per line: name, constraint and source separated by the
# unit separator; "extensions" of the configuration file maps names to a constraint or to { "version", "source" }
extensionProjectRequirements()
{
  local fileName="${1}"

  if [[ ! -f "${fileName}" ]]; then
    return 0
  fi

  jq -r '.extensions // {} | to_entries[] | [.key, (if (.value | type) == "object" then (.value.version // "*") else (.value // "*") end), (if (.value | type) == "object" then (.value.source // "") else "" end)] | join("\u001f")' "${fileName}" 2>/dev/null || true
}

# shellcheck disable=SC2034
typeset -fx extensionProjectRequirements

# prints one line per extension a system configuration requires that is missing or has an unsuitable version, with the
# command that solves it: extensionProjectProblems <configuration file> <label> <base path>... (the first base path
# that has the extension counts)
extensionProjectProblems()
{
  local fileName="${1}"
  local label="${2}"
  shift 2
  local basePaths=( "$@" )
  local basePath
  local name
  local constraint
  local version

  # the third field, the source, is only used for installing
  while IFS=$'\x1f' read -r name constraint _; do
    if [[ -z "${name}" ]]; then
      continue
    fi
    version=
    for basePath in "${basePaths[@]}"; do
      version=$(extensionInstalledVersion "${basePath}" "${name}")
      if [[ -n "${version}" ]]; then
        break
      fi
    done
    if [[ -z "${version}" ]]; then
      echo "System: ${label} requires extension: ${name} ${constraint}, which is not installed, run: ads extension install (in: $(dirname "${fileName}"))"
      continue
    fi
    if [[ "${version}" == "linked" ]] || [[ "${version}" == "local" ]] || { [[ "${version}" == "dev" ]] && [[ "${constraint}" != "dev" ]]; }; then
      continue
    fi
    if [[ $(versionSatisfies "${version}" "${constraint}") != 1 ]]; then
      echo "System: ${label} requires extension: ${name} ${constraint}, installed is: ${version}, run: ads extension update ${name}"
    fi
  done < <(extensionProjectRequirements "${fileName}")
}

# shellcheck disable=SC2034
typeset -fx extensionProjectProblems
