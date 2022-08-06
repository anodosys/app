#!/bin/bash -e

volumeExists()
{
  local volumeName="${1}"
  docker volume ls | tail -n +2 | awk '{print $2}' | grep -E "^${volumeName}\$" | wc -l
}

# shellcheck disable=SC2034
typeset -fx volumeExists
