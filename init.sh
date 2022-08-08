#!/bin/bash -e

if [[ $(which git | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: git"
  exit 1
fi

if [[ $(which head | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: head"
  exit 1
fi

if [[ $(which sed | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: sed"
  exit 1
fi

if [[ $(which wget | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: wget"
  exit 1
fi

if [[ $(which unzip | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: unzip"
  exit 1
fi

echo "Determining latest hash"
gitHash=$(git ls-remote https://bitbucket.org/tofex/anodosys.git 2>&1)
if [[ -z "${gitHash}" ]]; then
  echo "Could not list remote hashes, try again in 3 seconds"
  sleep 3
  gitHash=$(git ls-remote https://bitbucket.org/tofex/anodosys.git 2>&1)
  if [[ -z "${gitHash}" ]]; then
    echo "Could not list remote hashes, try again in another 3 seconds"
    sleep 3
    gitHash=$(git ls-remote https://bitbucket.org/tofex/anodosys.git 2>&1)
    if [[ -z "${gitHash}" ]]; then
      >&2 echo "Could not list remote hashes, giving up"
      exit 1
    fi
  fi
fi
hash=$(echo "${gitHash}" | head -1 | sed "s/HEAD//" | head -c 12)
if [[ -z "${hash}" ]]; then
  >&2 echo "Could not determine latest hash"
  exit 1
fi
echo "Latest hash: ${hash}"

basePath="/usr/local/lib"

applicationPath="${basePath}/tofex-anodosys-${hash}"

if [[ -L ${basePath}/anodosys ]]; then
  echo "Removing old version"
  rm ${basePath}/anodosys
fi
mkdir -p ${basePath}/
cd ${basePath}/

if [[ -d "${applicationPath}" ]]; then
  echo "Latest version already downloaded"
else
  echo "Downloading latest version: https://bitbucket.org/tofex/anodosys/get/${hash}.zip"
  result=$(wget -nv "https://bitbucket.org/tofex/anodosys/get/${hash}.zip" 2>&1)

  if [[ ! -f "${hash}.zip" ]]; then
    if [[ "${result}" =~ "ERROR 429" ]]; then
      counter=0

      until [[ ${counter} -gt 20 ]]; do
        ((counter++))
        echo "Waiting three seconds to avoid too many requests timeout"
        sleep 3
        echo "Downloading latest version: https://bitbucket.org/tofex/anodosys/get/${hash}.zip (retry #${counter})"
        wget -nv "https://bitbucket.org/tofex/anodosys/get/${hash}.zip"
        if [[ -f "${hash}.zip" ]]; then
          break;
        fi
      done
    else
      >&2 echo "${result}"
      exit 1
    fi
  fi

  if [[ ! -f "${hash}.zip" ]]; then
    >&2 echo "Download failed"
    exit 1
  fi

  echo "Extracting latest version"
  unzip -o -q "${hash}.zip"

  echo "Removing download"
  rm -rf "${hash}.zip"
fi

cd "${applicationPath}"

echo "Application downloaded at: ${applicationPath}"

echo "Linking application to: ${basePath}/anodosys"
ln -s "${applicationPath}" ${basePath}/anodosys

if [[ ! -f "/usr/local/bin/anodosys" ]]; then
  echo "Linking script from: ${basePath}/anodosys/anodosys.sh to: /usr/local/bin/anodosys"
  ln -s ${basePath}/anodosys/anodosys.sh /usr/local/bin/anodosys
fi

if [[ ! -f "/usr/local/bin/ads" ]]; then
  echo "Linking script from: ${basePath}/anodosys/anodosys.sh to: /usr/local/bin/ads"
  ln -s ${basePath}/anodosys/anodosys.sh /usr/local/bin/ads
fi

if [[ ! -f "/usr/local/bin/ads-ext" ]]; then
  echo "Linking script from: ${basePath}/anodosys/extension.sh to: /usr/local/bin/ads-ext"
  ln -s ${basePath}/anodosys/extension.sh /usr/local/bin/ads-ext
fi

if [[ ! -f "/usr/local/bin/ads-host" ]]; then
  echo "Linking script from: ${basePath}/anodosys/host.sh to: /usr/local/bin/ads-host"
  ln -s ${basePath}/anodosys/host.sh /usr/local/bin/ads-host
fi

if [[ ! -f "/usr/local/bin/ads-jump" ]]; then
  echo "Linking script from: ${basePath}/anodosys/jump.sh to: /usr/local/bin/ads-jump"
  ln -s ${basePath}/anodosys/jump.sh /usr/local/bin/ads-jump
fi

if [[ ! -f "/usr/local/bin/ads-update" ]]; then
  echo "Linking script from: ${basePath}/anodosys/update.sh to: /usr/local/bin/ads-update"
  ln -s ${basePath}/anodosys/update.sh /usr/local/bin/ads-update
fi

anodosysConfigurationPath="${applicationPath}/configuration"
mkdir -p "${anodosysConfigurationPath}"

anodosysExtensionPath="${applicationPath}/extension"
mkdir -p "${anodosysExtensionPath}"

anodosysHostPath="${applicationPath}/host"
mkdir -p "${anodosysHostPath}"

anodosysScriptPath="${applicationPath}/script"
mkdir -p "${anodosysScriptPath}"
