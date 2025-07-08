#!/bin/bash -e

containerPortBlocked()
{
  local containerName="${1}"
  local ports
  local port
  local portBlocked

  if [[ $(containerExists "${containerName}") == 1 ]] && [[ $(containerRunning "${containerName}") == 0 ]]; then
    ports=( $(containerPortHostList "${containerName}") )
    for port in "${ports[@]}"; do
      readarray -d / -t portParts < <(printf '%s' "${port}")
      port="${portParts[0]}"
      protocol="${portParts[1]}"
      portBlocked=$(bash -c "echo > /dev/${protocol}/127.0.0.1/${port}" 2>/dev/null && echo 1 || echo 0)
      if [[ "${portBlocked}" == 1 ]]; then
        echo 1
        exit 0
      fi
    done
  fi
  echo 0
}

# shellcheck disable=SC2034
typeset -fx containerPortBlocked
