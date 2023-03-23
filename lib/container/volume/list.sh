#!/bin/bash -e

containerVolumeNameList()
{
  local containerName="${1}"

  docker inspect -f "{{ json .Mounts }}" "${containerName}" | jq -r '.[].Name // empty'
}

# shellcheck disable=SC2034
typeset -fx containerVolumeNameList

containerVolumeSourcePathList()
{
  local containerName="${1}"

  docker inspect -f "{{ json .Mounts }}" "${containerName}" | jq -r '.[].Source // empty'
}

# shellcheck disable=SC2034
typeset -fx containerVolumeSourcePathList
