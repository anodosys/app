#!/bin/bash -e

imageId()
{
  local imageName="${1}"
  local imageTag="${2}"

  docker images --all --format "{{.Repository}} {{.Tag}} {{.ID}}" | grep -E "^${imageName,,}\\s+${imageTag,,}\\s" | awk '{print $3}'
}

# shellcheck disable=SC2034
typeset -fx imageId
