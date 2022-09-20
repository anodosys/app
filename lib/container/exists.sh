#!/bin/bash -e

containerExists()
{
  local containerName="${1}"

  docker ps -a | grep -E "\\s${containerName}\$" | wc -l
}

# shellcheck disable=SC2034
typeset -fx containerExists
