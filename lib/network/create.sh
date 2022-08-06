#!/bin/bash -e

networkCreate()
{
  local networkName="${1}"
  if [[ $(networkExists "${networkName}") == 0 ]]; then
    echo "Creating network: ${networkName}"
    result=$(docker network create "${networkName}" 2>&1 | cat)
    if [[ $(networkExists "${networkName}") == 1 ]]; then
      echo "Successfully created network: ${networkName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create network: ${networkName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create network: ${networkName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx networkCreate
