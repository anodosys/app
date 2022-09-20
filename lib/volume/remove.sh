#!/bin/bash -e

volumeRemove()
{
  local volumeName="${1}"
  local result

  if [[ $(volumeExists "${volumeName}") == 1 ]]; then
    echo "Removing volume: ${volumeName}"
    result=$(docker volume rm -f "${volumeName}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully removed volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove volume: ${volumeName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx volumeRemove
