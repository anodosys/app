#!/bin/bash -e

containerRemove()
{
  local containerName="${1}"
  local volumeNames
  local volumeName
  local result

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeNames=( $(containerVolumeList "${containerName}" ) )
    IFS="${oldIFS}"
    echo "Removing container: ${containerName}"
    result=$(docker rm "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully removed container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
    for volumeName in "${volumeNames[@]}"; do
      volumeName=$(trim "${volumeName}")
      volumeRemove "${volumeName}"
    done
  else
    echo "No need to remove container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRemove
