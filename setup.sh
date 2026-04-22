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

distribution=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
distributionVersion=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distribution}" == "Ubuntu" ]]; then
  basePath="/usr/local"
  binPath="${basePath}/bin"
  libPath="${basePath}/lib"
  anodosysPath="${libPath}/anodosys"
else
  >&2 echo "Unsupported OS: ${distribution}"
  exit 1
fi

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
  echo "Preparing distribution detection"

  if ! [[ -x "$(command -v lsb_release)" ]]; then
    echo "Installing lsb_release"
    if [[ "${distribution}" == "Ubuntu" ]]; then
      if [[ $(printf '%s\n' "18.04" "${distributionVersion}" | sort -C -V && echo "yes" || echo "no") == "yes" ]]; then
        apt-get update --allow-releaseinfo-change
      else
        apt-get update
      fi
      DEBIAN_FRONTEND="noninteractive" apt-get install -y apt-utils
      DEBIAN_FRONTEND="noninteractive" apt-get install -y lsb-release
    else
      >&2 echo "Unsupported OS: ${distribution}"
      exit 1
    fi
  fi

  echo "Finished preparing distribution detection"

  if [[ "${distribution}" == "Ubuntu" ]]; then
    if [[ $(printf '%s\n' "18.04" "${distributionVersion}" | sort -C -V && echo "yes" || echo "no") == "yes" ]]; then
      apt-get update --allow-releaseinfo-change
    else
      apt-get update
    fi
  else
    >&2 echo "Unsupported OS: ${distribution}"
    exit 1
  fi

  if [[ "${distribution}" == "Ubuntu" ]]; then
    requiredPackages=( git head moreutils sed wget unzip )
  else
    >&2 echo "Unsupported OS: ${distribution}"
    exit 1
  fi

  for requiredPackage in "${requiredPackages[@]}"; do
    if ! [[ -x "$(command -v "${requiredPackage}")" ]]; then
      echo "Installing package: ${requiredPackage}"
      if [[ "${distribution}" == "Ubuntu" ]]; then
        DEBIAN_FRONTEND="noninteractive" apt-get install -y "${requiredPackage}" 2>&1
      else
        >&2 echo "Unsupported OS: ${distribution}"
        exit 1
      fi
    else
      echo "${requiredPackage} already installed."
    fi
  done

  if [[ -n "${applicationVersion}" ]]; then
    gitReleaseUrl="https://api.github.com/repos/anodosys/app/releases/tags/${applicationVersion}"
  else
    gitReleaseUrl="https://api.github.com/repos/anodosys/app/releases/latest"
  fi

  echo "Determining release data"
  releaseData=$(curl -s "${gitReleaseUrl}" 2>/dev/null | cat)
  if [[ -z "${releaseData}" ]]; then
    counter=0
    until [[ "${counter}" -gt 20 ]]; do
      ((counter++))
      >&2 echo "Could not determine release data. Waiting three seconds to avoid too many requests timeout."
      sleep 3
      echo "Determining release data (retry #${counter})"
      releaseData=$(curl -s "${gitReleaseUrl}" 2>/dev/null | cat)
      if [[ -n "${releaseData}" ]]; then
        break;
      fi
    done
  fi

  if [[ -z "${releaseData}" ]]; then
    >&2 echo "Could not determine release data."
    exit 1
  fi

  releaseVersion=$(echo "${releaseData}" | jq -r '.tag_name')
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
        until [[ "${counter}" -gt 20 ]]; do
          ((counter++))
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

if [[ -L "${currentReleasePath}" ]]; then
  if ! [[ $(readlink -f "${currentReleasePath}") == "${releasePath}" ]]; then
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
  ln -s "${currentReleasePath}/host.sh" "${binPath}/jump.sh"
fi

if [[ ! -f "${binPath}/ads-update" ]]; then
  echo "Linking update script from: ${currentReleasePath}/update.sh to: ${binPath}/ads-update"
  ln -s "${currentReleasePath}/update.sh" "${binPath}/ads-update"
fi

anodosysConfigurationPath="${currentReleasePath}/configuration"
mkdir -p "${anodosysConfigurationPath}"

anodosysExtensionPath="${currentReleasePath}/extension"
mkdir -p "${anodosysExtensionPath}"

anodosysHostPath="${currentReleasePath}/host"
mkdir -p "${anodosysHostPath}"

anodosysActionPath="${currentReleasePath}/action"
anodosysActionSystemPath="${anodosysActionPath}/system"
mkdir -p "${anodosysActionSystemPath}"
anodosysActionServerPath="${anodosysActionPath}/server"
mkdir -p "${anodosysActionServerPath}"
