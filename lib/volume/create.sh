#!/bin/bash -e

volumeCreate()
{
  local volumeName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-local}"
  local mode="${5:-r}"
  local result

  if [[ $(volumeExists "${volumeName}") == 0 ]]; then
    echo "Creating volume: ${volumeName} with source path: ${sourcePath} and target path: ${targetPath} accessible by user: ${targetUser} and mode: ${mode}"
    result=$(docker volume create \
      --driver local \
      --opt type=none \
      --opt device="${sourcePath}" \
      --opt o=bind \
      --name "${volumeName}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully created volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create volume: ${volumeName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx volumeCreate
