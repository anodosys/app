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

applicationPath="/opt/install/tofex-anodosys-${hash}"

if [[ -L /opt/install/anodosys ]]; then
  echo "Removing old version"
  rm /opt/install/anodosys
fi
mkdir -p /opt/install/
cd /opt/install/

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

echo "Linking application to: /opt/install/anodosys"
ln -s "${applicationPath}" /opt/install/anodosys

if [[ ! -f "/usr/local/bin/anodosys" ]]; then
  echo "Linking script from: /opt/install/anodosys/anodosys.sh to: /usr/local/bin/anodosys"
  ln -s /opt/install/anodosys/anodosys.sh /usr/local/bin/anodosys
fi

if [[ ! -f "/usr/local/bin/ads" ]]; then
  echo "Linking script from: /opt/install/anodosys/anodosys.sh to: /usr/local/bin/ads"
  ln -s /opt/install/anodosys/anodosys.sh /usr/local/bin/ads
fi

anodosysConfigurationPath="${applicationPath}/configuration"
mkdir -p "${anodosysConfigurationPath}"
export anodosysConfigurationPath

anodosysScriptPath="${applicationPath}/script"
mkdir -p "${anodosysScriptPath}"
export anodosysScriptPath

anodosysExtensionPath="${applicationPath}/extension"
mkdir -p "${anodosysExtensionPath}"
export anodosysExtensionPath
