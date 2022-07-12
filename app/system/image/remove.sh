#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image remove -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageRemoveScript}" ]]; then
  echo "Before image remove script: ${beforeImageRemoveScript}"
  "${beforeImageRemoveScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  removeScript="${PWD}/${serverName}/image/remove.sh"
  if [[ -f "${removeScript}" ]]; then
    echo "[${serverName}] Removing image of server: ${serverName} with custom script: ${removeScript}"
    "${removeScript}" &
  else
    "${currentPath}/../../server/image/remove.sh" -s "${serverName}" &
  fi
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageRemoveScript}" ]]; then
  echo "After image remove script: ${afterImageRemoveScript}"
  "${afterImageRemoveScript}"
fi
