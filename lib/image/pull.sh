#!/bin/bash -e

imagePull()
{
  local imageName="${1}"
  local imageTag="${2}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
    echo "Pulling image: ${imageName}:${imageTag}"
    logDisable
    docker pull "${imageName}:${imageTag}"
    logEnable
  else
    echo "No need to pull image: ${imageName}:${imageTag}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imagePull
