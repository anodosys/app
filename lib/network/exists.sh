#!/bin/bash -e

networkExists()
{
  local networkName="${1}"

  docker network ls | tail -n +2 | awk '{print $2}' | grep -E "^${networkName}\$" | wc -l
}

# shellcheck disable=SC2034
typeset -fx networkExists
