#!/bin/bash -e

containerPortAvailable()
{
  local containerName="${1}"
  local ports
  local portParts
  local port
  local protocol
  local portAvailable

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    ports=( $(containerPortList "${containerName}") )
    for port in "${ports[@]}"; do
      readarray -d / -t portParts < <(printf '%s' "${port}")
      port="${portParts[0]}"
      protocol="${portParts[1]}"
      portAvailable=$(docker exec "${containerName}" bash -c "echo > /dev/${protocol}/127.0.0.1/${port} 2>/dev/null && echo 1 || echo 0" 2>/dev/null || echo 0)
      if [[ "${portAvailable}" == 0 ]]; then
        echo 0
        exit 0
      fi
    done
    echo 1
  else
    echo 0
  fi
}

# shellcheck disable=SC2034
typeset -fx containerPortAvailable
