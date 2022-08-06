#!/bin/bash -e

containerHostNameAdd()
{
  local containerName="${1}"
  local ipAddress=
  ipAddress=$(docker inspect -f "{{ json .NetworkSettings }}" "${containerName}" | jq -r '.Networks[].IPAddress')
  if [[ -f /etc/hosts ]]; then
    if [[ -w /etc/hosts ]]; then
      if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -eq 0 ]]; then
        echo "Adding host entry: ${ipAddress} ${containerName}" | sed $'s,.*,\e[1;32m&\e[m,'
        echo "${ipAddress} ${containerName}" >> /etc/hosts
      else
        lineNumber=$(grep -En "\s+${containerName}\s*$" /etc/hosts | awk -F: '{print $1}')
        echo "Update host entry: ${ipAddress} ${containerName}" | sed $'s,.*,\e[1;32m&\e[m,'
        sed -i "${lineNumber}s/.*/${ipAddress} ${containerName}/" /etc/hosts
      fi
    else
      echo "/etc/hosts is not writable for current user, add:" | sed $'s,.*,\e[0;33m&\e[m,'
      echo "${ipAddress} ${containerName}" | sed $'s,.*,\e[0;33m&\e[m,'
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerHostNameAdd
