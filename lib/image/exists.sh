#!/bin/bash -e

imageExists()
{
  local imageName="${1}"
  local imageTag="${2}"
  docker images | grep -E "^${imageName}\\s+${imageTag}\\s" | wc -l
}

# shellcheck disable=SC2034
typeset -fx imageExists

imageExistsRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  docker manifest inspect "${imageName}:${imageTag}" >/dev/null 2>&1 && echo 1 || echo 0
}

# shellcheck disable=SC2034
typeset -fx imageExistsRemote
