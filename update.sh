#!/bin/bash -e

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

wget --no-cache -nv -O - https://bitbucket.org/tofex/anodosys/raw/master/init.sh | bash

if [[ "${currentPath}" == "${PWD}" ]]; then
  cd "${currentPath}"
fi
