#!/bin/bash -e

containerRun()
{
  local imageName="${1}"
  local containerName="${2}"

  if [[ $(containerRunning "${containerName}") == 0 ]]; then
    echo "Running container: ${containerName}"
    docker run -itd --name "${containerName}" "${imageName}"
    containerHostNameAdd "${containerName}"
  else
    echo "No need to start container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRun
