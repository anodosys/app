#!/bin/bash -e

if [[ $(id -u) != 0 ]]; then
  >&2 echo "Updating requires root privileges, please run it with sudo"
  exit 1
fi

wget --no-cache -q -O - https://raw.githubusercontent.com/anodosys/app/master/setup.sh | bash -s -- "$@"
