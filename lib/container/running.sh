#!/bin/bash -e

containerRunning()
{
  local containerName="${1}"

  docker ps | grep -E "\\s${containerName}\$" | wc -l
}

# shellcheck disable=SC2034
typeset -fx containerRunning
