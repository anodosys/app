#!/bin/bash -e

containerHostNameRemove()
{
  local containerName="${1}"
  local lineNumber

  if [[ -f /etc/hosts ]]; then
    if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -gt 0 ]]; then
      lineNumber=$(grep -En "\s+${containerName}\s*$" /etc/hosts | awk -F: '{print $1}')
      echo "Removing host entry: ${containerName}"
      sed -i "${lineNumber}d" /etc/hosts
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerHostNameRemove
