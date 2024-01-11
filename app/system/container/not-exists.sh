#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container not exists -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerNotExistsScript}" ]]; then
  echo "Before container not exists script: ${beforeContainerNotExistsScript}"
  if [[ -n "${beforeContainerNotExistsParameters}" ]]; then
    "${beforeContainerNotExistsScript}" \
      --systemName "${systemName}" \
      "${beforeContainerNotExistsParameters[@]}"
  else
    "${beforeContainerNotExistsScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# break if any container already exists
declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  existsScript="${PWD}/${serverName}/container/exists.sh"
  if [[ -f "${existsScript}" ]]; then
    "${existsScript}" -s "${serverName}" &
  else
    "${currentPath}/../../server/container/not-exists.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterContainerNotExistsScript}" ]]; then
  echo "After container not exists script: ${afterContainerNotExistsScript}"
  if [[ -n "${afterContainerNotExistsParameters}" ]]; then
    "${afterContainerNotExistsScript}" \
      --systemName "${systemName}" \
      "${afterContainerNotExistsParameters[@]}"
  else
    "${afterContainerNotExistsScript}" \
      --systemName "${systemName}"
  fi
fi
