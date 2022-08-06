#!/bin/bash -e

containerStop()
{
  local containerName="${1}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Stopping container: ${containerName}"
    result=$(docker stop "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully stopped container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not stop container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
    containerHostNameRemove "${containerName}"
  else
    echo "No need to stop container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerStop
