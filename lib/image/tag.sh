#!/bin/bash -e

imageTag()
{
  local imageId="${1}"

  docker image ls -a | awk '{print $1,$2,$3}' | grep -E "\s${imageId}$" | awk '{print $2}'
}

# shellcheck disable=SC2034
typeset -fx imageTag
