#!/bin/bash -e

containerPortList()
{
  local containerName="${1}"
  docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".NetworkSettings .Ports | keys[] // empty"
}

# shellcheck disable=SC2034
typeset -fx containerPortList
