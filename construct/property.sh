#!/bin/bash -e

usage()
{
cat >&2 << EOF

usage: ads construct property --option value

OPTIONS:
  --serverName  The name of server (optional)
  --name        The name of the property
  --value       The value of the property
  --overwrite   Flag to overwrite the value if already exists
  --append      Flag to append the value to a list
  --raw         Flag to add the value as string

Example: ads construct property --serverName global --name systemName --value project --overwrite
EOF
}

if [[ -n "${helpRequested}" ]] && [[ "${helpRequested}" -eq 1 ]]; then
  usage
  exit 0
fi

if [[ -z "${name}" ]]; then
  >&2 echo "No property name defined!"
  usage
  exit 1
fi

if [[ -z "${value}" ]]; then
  >&2 echo "No property value defined!"
  usage
  exit 1
fi

if [[ -z "${overwrite}" ]]; then
  overwrite=0
fi

if [[ -z "${append}" ]]; then
  append=0
fi

if [[ -z "${raw}" ]]; then
  raw=0
fi

if [[ -n "${serverName}" ]]; then
  addServerProperty "${serverName}" "${name}" "${value}" "${overwrite}" "${append}" "${raw}"
else
  addProperty "${name}" "${value}" "${overwrite}" "${append}" "${raw}"
fi
