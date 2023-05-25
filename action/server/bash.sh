#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

shift
serverName="${1}"
shift

if [[ -n "${1}" ]]; then
  userName="${1}"
  if [[ "${userName}" == "me" ]]; then
    userName="${USER}"
  fi
  shift
else
  userName="none"
fi

"${anodosysAppPath}/server/container/command.sh" \
  -s "${serverName}" \
  -u "${userName}" \
  -c "bash --rcfile <(echo 'cd ~')" \
  -i \
  -q
