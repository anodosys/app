#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container running -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerRunningScript}" ]]; then
  echo "Before container running script: ${beforeContainerRunningScript}"
  "${beforeContainerRunningScript}"
fi

# break if not all containers are running
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  containerName="${systemName}_${serverName}"
  if [[ $(containerRunning "${containerName}") == 0 ]]; then
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
done

if [[ -n "${afterContainerRunningScript}" ]]; then
  echo "After container running script: ${afterContainerRunningScript}"
  "${afterContainerRunningScript}"
fi
