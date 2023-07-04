#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

shift

if [[ -z "${1}" ]]; then
  >&2 echo "No server name specified"
  exit 1
fi

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

if [[ "${#@}" == 0 ]]; then
  >&2 echo "No command specified"
  exit 1
fi

if [[ -z "${command}" ]]; then
  command=( "${@}" )
fi

"${anodosysAppPath}/server/container/command.sh" \
  -s "${serverName}" \
  -u "${userName}" \
  -c "${command[@]}"
