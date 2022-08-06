#!/bin/bash -e

networkRemove()
{
  local networkName="${1}"
  if [[ $(networkExists "${networkName}") == 1 ]]; then
    echo "Removing network: ${networkName}"
    result=$(docker network rm "${networkName}" 2>&1 | cat)
    if [[ "${result}" == "${networkName}" ]]; then
      echo "Successfully removed network: ${networkName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove network: ${networkName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove network: ${networkName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx networkRemove
