#!/bin/bash -e

containerIp()
{
  local containerName="${1}"

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerIp
