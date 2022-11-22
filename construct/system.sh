#!/bin/bash -e

usage()
{
cat >&2 << EOF

usage: ads construct system --option value

OPTIONS:
  --name       The name of the system
  --overwrite  Flag to overwrite the value if already exists

Example: ads construct system --name app
EOF
}

if [[ -n "${helpRequested}" ]] && [[ "${helpRequested}" -eq 1 ]]; then
  usage
  exit 0
fi

if [[ -z "${name}" ]]; then
  >&2 echo "No system name defined!"
  usage
  exit 1
fi

if [[ -z "${overwrite}" ]]; then
  overwrite=0
fi

addServerProperty "global" "systemName" "${name}" "${overwrite}"
