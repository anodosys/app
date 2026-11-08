#!/bin/bash -e

containerHostNameAdd()
{
  local containerName="${1}"
  local ipAddress
  local hosts

  # a container can be in several networks (for example the one of the proxy), the address in the network of its system
  # is used, otherwise the first one
  # shellcheck disable=SC2154
  ipAddress=$(docker inspect -f "{{ json .NetworkSettings }}" "${containerName}" \
    | jq -r --arg network "${systemName}" '.Networks[$network].IPAddress // ([.Networks[].IPAddress] | first) // empty')
  if [[ -f /etc/hosts ]]; then
    if [[ -w /etc/hosts ]]; then
      if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -eq 0 ]]; then
        echo "Adding host entry: ${ipAddress} ${containerName}" | sed $'s,.*,\e[1;32m&\e[m,'
        echo "${ipAddress} ${containerName}" >> /etc/hosts
      else
        echo "Update host entry: ${ipAddress} ${containerName}" | sed $'s,.*,\e[1;32m&\e[m,'
        # the content is written back instead of replacing the file (sed -i), which fails when /etc/hosts is a mount
        # point, for example inside a container
        hosts=$(sed -E "s/^.*\s+${containerName}\s*$/${ipAddress} ${containerName}/" /etc/hosts)
        printf '%s\n' "${hosts}" > /etc/hosts
      fi
    else
      echo "/etc/hosts is not writable for current user, add:" | sed $'s,.*,\e[0;33m&\e[m,'
      echo "${ipAddress} ${containerName}" | sed $'s,.*,\e[0;33m&\e[m,'
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerHostNameAdd
