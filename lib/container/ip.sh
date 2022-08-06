#!/bin/bash -e

containerIp()
{
  local containerName="${1}"
  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containerName}"
}

# shellcheck disable=SC2034
typeset -fx containerIp
