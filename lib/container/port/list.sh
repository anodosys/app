#!/bin/bash -e

containerPortList()
{
  local containerName="${1}"
  docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".NetworkSettings .Ports | keys[] // empty"
}

# shellcheck disable=SC2034
typeset -fx containerPortList

containerPortHostList()
{
  local containerName="${1}"
  docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".HostConfig .PortBindings[][] .HostPort // empty"
}

# shellcheck disable=SC2034
typeset -fx containerPortHostList
