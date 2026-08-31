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
  echo "Before system container running script: ${beforeContainerRunningScript}"
  if [[ -n "${beforeContainerRunningParameters}" ]]; then
    "${beforeContainerRunningScript}" \
      --systemName "${systemName}" \
      "${beforeContainerRunningParameters[@]}"
  else
    "${beforeContainerRunningScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  runningScript="${PWD}/${serverName}/container/running.sh"
  if [[ -f "${runningScript}" ]]; then
    "${runningScript}" -s "${serverName}" &
  else
    "${currentPath}/../../server/container/running.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterContainerRunningScript}" ]]; then
  echo "After system container running script: ${afterContainerRunningScript}"
  if [[ -n "${afterContainerRunningParameters}" ]]; then
    "${afterContainerRunningScript}" \
      --systemName "${systemName}" \
      "${afterContainerRunningParameters[@]}"
  else
    "${afterContainerRunningScript}" \
      --systemName "${systemName}"
  fi
fi
