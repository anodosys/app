#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

interactive=0
if [[ "${action}" == "bash" ]]; then
  action="cmd"
  command="bash --rcfile <(echo 'cd ~')"
  interactive=1
fi

if [[ "${action}" == "cmd" ]]; then
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
  if [[ -z "${command}" ]]; then
    command=( "${@}" )
  fi
  if [[ "${interactive}" == 1 ]]; then
    "${anodosysAppPath}/server/container/command.sh" -s "${serverName}" -u "${userName}" -c "${command[@]}" -i
  else
    "${anodosysAppPath}/server/container/command.sh" -s "${serverName}" -u "${userName}" -c "${command[@]}"
  fi
  exit 0
fi
