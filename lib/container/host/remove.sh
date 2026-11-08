#!/bin/bash -e

containerHostNameRemove()
{
  local containerName="${1}"
  local hosts

  if [[ -f /etc/hosts ]] && [[ -w /etc/hosts ]]; then
    if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -gt 0 ]]; then
      echo "Removing host entry: ${containerName}"
      # the content is written back instead of replacing the file (sed -i), which fails when /etc/hosts is a mount point,
      # for example inside a container
      hosts=$(grep -Ev "\s+${containerName}\s*$" /etc/hosts || true)
      printf '%s\n' "${hosts}" > /etc/hosts
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerHostNameRemove
