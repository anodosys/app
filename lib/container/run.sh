#!/bin/bash -e

containerRun()
{
  local imageName="${1}"
  local containerName="${2}"
  local containerCommand="${3}"

  if [[ $(containerRunning "${containerName}") == 0 ]]; then
    if [[ -n "${containerCommand}" ]]; then
      echo "Running container: ${containerName} with command: ${containerCommand}"
      docker run -itd --name "${containerName}" "${imageName}" "${containerCommand}"
    else
      echo "Running container: ${containerName}"
      docker run -itd --name "${containerName}" "${imageName}"
    fi
    containerHostNameAdd "${containerName}"
  else
    echo "No need to start container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRun
