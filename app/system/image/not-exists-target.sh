#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Target image not exists -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageNotExistsTargetScript}" ]]; then
  echo "Before target image not exists script: ${beforeImageNotExistsTargetScript}"
  "${beforeImageNotExistsTargetScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  "${currentPath}/../../server/image/not-exists-target.sh" -s "${serverName}" &
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageNotExistsTargetScript}" ]]; then
  echo "After target image not exists script: ${afterImageNotExistsTargetScript}"
  "${afterImageNotExistsTargetScript}"
fi
