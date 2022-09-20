#!/bin/bash -e

imagePush()
{
  local imageName="${1}"
  local imageTag="${2}"

  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Pushing image: ${imageName}:${imageTag}"
    exec >/dev/tty
    exec 2>/dev/tty
    logDisable
    docker push "${imageName}:${imageTag}"
    logEnable
  else
    >&2 echo "Image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx imagePush
