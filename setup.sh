#!/bin/bash -e

applicationVersion=
force=0

declare -Ag prepareParameters
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter:0:2}" == "--" ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      parameter="${parameter:2}"
      prepareParametersKey=$(echo "${parameter}" | grep -oP '[[:alpha:]]+(?=\s)' | tr -d "\n")
      prepareParametersValue=$(echo "${parameter:${#prepareParametersKey}}" | xargs)
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      continue
    fi
    if [[ "${parameter:0:2}" == "--" ]]; then
      prepareParametersKey="${parameter:2}"
    elif [[ "${parameter}" =~ ^-\?$ ]]; then
      prepareParametersKey="help"
    else
      prepareParametersKey="${parameter:1}"
    fi
    if [[ "$#" -eq 0 ]]; then
      prepareParameters["${prepareParametersKey}"]=1
      #echo eval "${prepareParametersKey}=1"
      eval "${prepareParametersKey}=1"
    else
      prepareParametersValue="${1}"
      if [[ "${prepareParametersValue:0:2}" == "--" ]]; then
        prepareParameters["${prepareParametersKey}"]=1
        #echo eval "${prepareParametersKey}=1"
        eval "${prepareParametersKey}=1"
        continue
      fi
      shift
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
    fi
  else
    unparsedParameters+=("${parameter}")
  fi
done
set -- "${unparsedParameters[@]}"

prepareParametersList=()
for prepareParametersKey in "${!prepareParameters[@]}"; do
  prepareParametersList+=( "--${prepareParametersKey}" )
  prepareParametersValue="${prepareParameters[${prepareParametersKey}]}"
  prepareParametersList+=( "${prepareParametersValue}" )
done
for unparsedParametersKey in "${!unparsedParameters[@]}"; do
  unparsedParametersValue="${unparsedParameters[${unparsedParametersKey}]}"
  prepareParametersList+=( "${unparsedParametersValue}" )
done

# shellcheck disable=SC1091
distribution=$(. /etc/os-release && echo "${NAME}")
# shellcheck disable=SC1091
read -r -a distributionIds <<< "$(. /etc/os-release && echo "${ID} ${ID_LIKE}")"

# Ubuntu and Debian (and their derivatives) use apt, Fedora uses dnf
packageManager=
for distributionId in "${distributionIds[@]}"; do
  case "${distributionId}" in
    ubuntu|debian) packageManager="apt"; break;;
    fedora) packageManager="dnf"; break;;
  esac
done

if [[ -z "${packageManager}" ]]; then
  >&2 echo "Unsupported OS: ${distribution}, supported are Ubuntu, Debian and Fedora"
  exit 1
fi

if [[ $(id -u) != 0 ]]; then
  >&2 echo "Installing requires root privileges, please run it with sudo"
  exit 1
fi

basePath="/usr/local"
binPath="${basePath}/bin"
libPath="${basePath}/lib"
anodosysPath="${libPath}/anodosys"

mkdir -p "${binPath}"
mkdir -p "${libPath}"
mkdir -p "${anodosysPath}"

currentReleasePath="${anodosysPath}/current"

alreadyInstalled=0

if [[ -n "${applicationVersion}" ]]; then
  releasePath="${anodosysPath}/${applicationVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 0 ]]; then
    echo "Release already installed"
    alreadyInstalled=1
  fi
fi

if [[ "${alreadyInstalled}" == 0 ]]; then
  # required command and the package that contains it
  declare -A requiredCommands
  if [[ "${packageManager}" == "apt" ]]; then
    requiredCommands=( [curl]=curl [git]=git [jq]=jq [ts]=moreutils [sed]=sed [wget]=wget [unzip]=unzip [ps]=procps
      [find]=findutils [getent]=libc-bin [rsync]=rsync [awk]=gawk )
  else
    requiredCommands=( [curl]=curl [git]=git [jq]=jq [ts]=moreutils [sed]=sed [wget]=wget [unzip]=unzip [ps]=procps-ng
      [find]=findutils [getent]=glibc-common [rsync]=rsync [awk]=gawk )
  fi

  requiredPackages=( )
  for requiredCommand in "${!requiredCommands[@]}"; do
    if command -v "${requiredCommand}" >/dev/null 2>&1; then
      echo "${requiredCommand} already installed"
    else
      requiredPackages+=( "${requiredCommands[${requiredCommand}]}" )
    fi
  done

  if [[ "${#requiredPackages[@]}" -gt 0 ]]; then
    readarray -t requiredPackages < <(printf '%s\n' "${requiredPackages[@]}" | sort -u)
    echo "Installing packages: ${requiredPackages[*]}"
    if [[ "${packageManager}" == "apt" ]]; then
      apt-get update --allow-releaseinfo-change || apt-get update
      DEBIAN_FRONTEND="noninteractive" apt-get install -y "${requiredPackages[@]}" 2>&1
    else
      dnf install -y "${requiredPackages[@]}" 2>&1
    fi
  fi

  # jcp and j2v are self-contained binaries, so the same files work on every distribution
  case "$(uname -m)" in
    x86_64|amd64) toolPlatform="linux-x64";;
    aarch64|arm64) toolPlatform="linux-arm";;
    *) toolPlatform=;;
  esac

  for tool in jcp j2v; do
    if command -v "${tool}" >/dev/null 2>&1; then
      echo "${tool} already installed"
    elif [[ -z "${toolPlatform}" ]]; then
      >&2 echo "No ${tool} binary available for architecture: $(uname -m)"
      exit 1
    else
      toolUrl="https://raw.githubusercontent.com/fewe-dev/${tool}/refs/heads/master/build/linux/${toolPlatform}"
      echo "Installing ${tool} from url: ${toolUrl}"
      if ! wget -q -O "${binPath}/${tool}.download" "${toolUrl}"; then
        rm -f "${binPath}/${tool}.download"
        >&2 echo "Could not download ${tool} from url: ${toolUrl}"
        exit 1
      fi
      chmod 0755 "${binPath}/${tool}.download"
      mv "${binPath}/${tool}.download" "${binPath}/${tool}"
    fi
  done

  if [[ -n "${applicationVersion}" ]]; then
    gitReleaseUrl="https://api.github.com/repos/anodosys/app/releases/tags/${applicationVersion}"
  else
    gitReleaseUrl="https://api.github.com/repos/anodosys/app/releases/latest"
  fi

  # the release data is only accepted when it names a version, GitHub answers with an error page when it is unavailable
  determineReleaseData()
  {
    releaseData=$(curl -s "${gitReleaseUrl}" 2>/dev/null | cat)
    releaseVersion=$(echo "${releaseData}" | jq -r '.tag_name // empty' 2>/dev/null || true)
    [[ "${releaseVersion}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  }

  echo "Determining release data"
  if ! determineReleaseData; then
    counter=0
    until [[ "${counter}" -ge 20 ]]; do
      counter=$((counter+1))
      >&2 echo "Could not determine release data. Waiting three seconds to avoid too many requests timeout."
      sleep 3
      echo "Determining release data (retry #${counter})"
      if determineReleaseData; then
        break
      fi
    done
  fi

  if [[ ! "${releaseVersion}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    >&2 echo "Could not determine release data from url: ${gitReleaseUrl}"
    exit 1
  fi

  echo "Release version: ${releaseVersion}"

  if [[ ! -d "${anodosysPath}" ]]; then
    echo "Creating base path at: ${anodosysPath}"
    mkdir -p "${anodosysPath}"
  fi

  releasePath="${anodosysPath}/${releaseVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 1 ]]; then
    echo "Removing previously installed release"
    rm -rf "${releasePath}"
  fi

  if [[ -d "${releasePath}" ]]; then
    echo "Release already installed"
  else
    releaseZipUrl=$(echo "${releaseData}" | jq -r '.zipball_url')
    releaseZipPath="${anodosysPath}/${releaseVersion}.zip"

    echo "Downloading release archive from url: ${releaseZipUrl}"
    result=$(wget -q -O "${releaseZipPath}" "${releaseZipUrl}" 2>&1 | cat)

    if [[ ! -f "${releaseZipPath}" ]]; then
      if [[ "${result}" =~ "ERROR 429" ]]; then
        counter=0
        until [[ "${counter}" -ge 20 ]]; do
          counter=$((counter+1))
          echo "Could not download release archive. Waiting three seconds to avoid too many requests timeout"
          sleep 3
          echo "Downloading release archive from url: ${releaseZipUrl} (retry #${counter})"
          result=$(wget -q -O "${releaseZipPath}" "${releaseZipUrl}" 2>&1 | cat)
          if [[ -f "${releaseZipPath}" ]]; then
            break;
          fi
          if ! [[ "${result}" =~ "ERROR 429" ]]; then
            >&2 echo "${result}"
            exit 1
          fi
        done
      else
        >&2 echo "${result}"
        exit 1
      fi
    fi

    if [[ ! -f "${releaseZipPath}" ]]; then
      >&2 echo "Download failed"
      exit 1
    fi

    echo "Extracting downloaded release archive"
    unzip -o -q "${releaseZipPath}" -d "${releasePath}"

    echo "Removing downloaded release archive"
    rm -rf "${releaseZipPath}"

    echo "Release archive extracted to: ${releasePath}"
    cd "${releasePath}"
    releasePathGitPath=$(find . -maxdepth 1 -type d -name '[^.]?*' -printf %f -quit)

    echo "Found git directory: ${releasePathGitPath}"
    shopt -s dotglob
    mv -- "${releasePathGitPath}"/* .
    shopt -u dotglob

    echo "Removing git directory: ${releasePathGitPath}"
    rm -rf "${releasePathGitPath}"
  fi
fi

previousReleasePath=
if [[ -L "${currentReleasePath}" ]]; then
  previousReleasePath=$(readlink -f "${currentReleasePath}")
  if ! [[ "${previousReleasePath}" == "${releasePath}" ]]; then
    echo "Unlinking currently installed release"
    rm "${currentReleasePath}"
  fi
fi

if ! [[ -L "${currentReleasePath}" ]]; then
  echo "Linking installed release from: ${releasePath} to: ${currentReleasePath}"
  ln -s "${releasePath}" "${currentReleasePath}"
fi

if [[ ! -L "${binPath}/anodosys" ]]; then
  echo "Linking application script from: ${currentReleasePath}/anodosys.sh to: ${binPath}/anodosys"
  ln -s "${currentReleasePath}/anodosys.sh" "${binPath}/anodosys"
fi

if [[ ! -L "${binPath}/ads" ]]; then
  echo "Linking application script from: ${currentReleasePath}/anodosys.sh to: ${binPath}/ads"
  ln -s "${currentReleasePath}/anodosys.sh" "${binPath}/ads"
fi

if [[ ! -L "${binPath}/ads-ext" ]]; then
  echo "Linking extension script from: ${currentReleasePath}/extension.sh to: ${binPath}/ads-ext"
  ln -s "${currentReleasePath}/extension.sh" "${binPath}/ads-ext"
fi

if [[ ! -L "${binPath}/ads-host" ]]; then
  echo "Linking host script from: ${currentReleasePath}/host.sh to: ${binPath}/ads-host"
  ln -s "${currentReleasePath}/host.sh" "${binPath}/ads-host"
fi

if [[ ! -L "${binPath}/ads-jump" ]]; then
  echo "Linking jump script from: ${currentReleasePath}/jump.sh to: ${binPath}/ads-jump"
  ln -s "${currentReleasePath}/jump.sh" "${binPath}/ads-jump"
fi

if [[ ! -f "${binPath}/ads-update" ]]; then
  echo "Linking update script from: ${currentReleasePath}/update.sh to: ${binPath}/ads-update"
  ln -s "${currentReleasePath}/update.sh" "${binPath}/ads-update"
fi

anodosysConfigurationPath="${currentReleasePath}/configuration"
mkdir -p "${anodosysConfigurationPath}"

anodosysExtensionPath="${anodosysPath}/extension"
mkdir -p "${anodosysExtensionPath}"

# move extensions of the previous release, which stored them inside the release directory
for releaseExtensionPath in "${previousReleasePath}"/extension/*/; do
  if [[ -n "${previousReleasePath}" ]] && [[ -d "${releaseExtensionPath}" ]]; then
    releaseExtensionName=$(basename "${releaseExtensionPath}")
    if [[ ! -d "${anodosysExtensionPath}/${releaseExtensionName}" ]]; then
      echo "Moving extension: ${releaseExtensionName} to: ${anodosysExtensionPath}/${releaseExtensionName}"
      cp -a "${releaseExtensionPath}" "${anodosysExtensionPath}/${releaseExtensionName}"
    fi
  fi
done

# keep the current and the previous release only
for installedReleasePath in "${anodosysPath}"/*/; do
  installedReleasePath="${installedReleasePath%/}"
  installedReleaseVersion=$(basename "${installedReleasePath}")
  if [[ "${installedReleaseVersion}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "${installedReleasePath}" != "${releasePath}" ]] && [[ "${installedReleasePath}" != "${previousReleasePath}" ]]; then
    echo "Removing old release: ${installedReleaseVersion}"
    rm -rf "${installedReleasePath}"
  fi
done

anodosysHostPath="${currentReleasePath}/host"
mkdir -p "${anodosysHostPath}"

anodosysActionPath="${currentReleasePath}/action"
anodosysActionSystemPath="${anodosysActionPath}/system"
mkdir -p "${anodosysActionSystemPath}"
anodosysActionServerPath="${anodosysActionPath}/server"
mkdir -p "${anodosysActionServerPath}"
