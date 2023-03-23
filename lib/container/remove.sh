#!/bin/bash -e

containerRemove()
{
  local containerName="${1}"
  local useNamedVolumes="${2:-false}"
  local volumeNames
  local volumeName
  local volumeSourcePaths
  local volumeSourcePath
  local result

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ "${useNamedVolumes}" == "true" ]]; then
      oldIFS="${IFS}"
      IFS=$'\n'
      volumeNames=( $(containerVolumeNameList "${containerName}" ) )
      IFS="${oldIFS}"
    fi

    oldIFS="${IFS}"
    IFS=$'\n'
    volumeSourcePaths=( $(containerVolumeSourcePathList "${containerName}" ) )
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

    if [[ "${useNamedVolumes}" == "true" ]]; then
      for volumeName in "${volumeNames[@]}"; do
        volumeName=$(trim "${volumeName}")
        volumeRemove "${volumeName}"
      done
    fi

    for volumeSourcePath in "${volumeSourcePaths[@]}"; do
      volumeSourcePath=$(trim "${volumeSourcePath}")
      volumeMetadataFilePath=$(volumeMetadataFilePath "${volumeSourcePath}")

      rm -rf "${volumeMetadataFilePath}"
    done
  else
    echo "No need to remove container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRemove
