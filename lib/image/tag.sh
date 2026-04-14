#!/bin/bash -e

imageTag()
{
  local imageId="${1}"

  docker images --all --format "{{.Repository}} {{.Tag}} {{.ID}}" | grep -E "\s${imageId}$" | awk '{print $2}'
}

# shellcheck disable=SC2034
typeset -fx imageTag
