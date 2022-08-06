#!/bin/bash -e

containerVolumeRemove()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local sourceName=
  local volumeName
  if [[ -e "${sourcePath}" ]]; then
    sourcePath=$(realpath "${sourcePath}")
  fi
  sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
  volumeName="${containerName}_${sourceName}"
  volumeRemove "${volumeName}"
}

# shellcheck disable=SC2034
typeset -fx containerVolumeRemove
