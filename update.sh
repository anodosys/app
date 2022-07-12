#!/bin/bash -e

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

oldPath=$(readlink /usr/local/lib/anodosys)

wget --no-cache -nv -O - https://bitbucket.org/tofex/anodosys/raw/master/init.sh | sudo bash

if [[ "${currentPath}" == "${PWD}" ]]; then
  cd "${currentPath}"
fi

newPath=$(readlink /usr/local/lib/anodosys)

if [[ "${oldPath}" != "${newPath}" ]]; then
  if [[ -d "${oldPath}/configuration/" ]]; then
    sudo cp -ar "${oldPath}/configuration/" "${newPath}"
  fi
  if [[ -d "${oldPath}/extension/" ]]; then
    sudo cp -ar "${oldPath}/extension/" "${newPath}"
  fi
  if [[ -d "${oldPath}/host/" ]]; then
    sudo cp -ar "${oldPath}/host/" "${newPath}"
  fi
  if [[ -d "${oldPath}/script/" ]]; then
    sudo cp -ar "${oldPath}/script/" "${newPath}"
  fi
fi
