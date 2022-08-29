#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container not running -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerNotRunningScript}" ]]; then
  echo "Before container not running script: ${beforeContainerNotRunningScript}"
  "${beforeContainerNotRunningScript}"
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  notRunningScript="${PWD}/${serverName}/container/not-running.sh"
  if [[ -f "${notRunningScript}" ]]; then
    "${notRunningScript}" -s "${serverName}" &
  else
    "${currentPath}/../../server/container/not-running.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterContainerNotRunningScript}" ]]; then
  echo "After container not running script: ${afterContainerNotRunningScript}"
  "${afterContainerNotRunningScript}"
fi
