#!/bin/bash -e

containerVolumeList()
{
  local containerName="${1}"

  docker inspect -f "{{ json .Mounts }}" "${containerName}" | jq -r '.[].Name // empty'
}

# shellcheck disable=SC2034
typeset -fx containerVolumeList
