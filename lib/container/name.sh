#!/bin/bash -e

containerName()
{
  local containerId="${1}"

  docker inspect -f '{{.Name}}' "${containerId}" | cut -c2-
}

# shellcheck disable=SC2034
typeset -fx containerName
