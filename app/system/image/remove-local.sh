#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image remove local -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageRemoveLocalScript}" ]]; then
  echo "Before image remove local script: ${beforeImageRemoveLocalScript}"
  "${beforeImageRemoveLocalScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  removeScript="${PWD}/${serverName}/image/remove-local.sh"
  if [[ -f "${removeScript}" ]]; then
    echo "[${serverName}] Removing local image of server: ${serverName} with custom script: ${removeScript}"
    "${removeScript}" &
  else
    "${currentPath}/../../server/image/remove-local.sh" -s "${serverName}" &
  fi
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageRemoveLocalScript}" ]]; then
  echo "After image remove local script: ${afterImageRemoveLocalScript}"
  "${afterImageRemoveLocalScript}"
fi
