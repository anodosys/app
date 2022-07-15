#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image remove source local -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageRemoveSourceLocalScript}" ]]; then
  echo "Before image remove source local script: ${beforeImageRemoveSourceLocalScript}"
  "${beforeImageRemoveSourceLocalScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  removeScript="${PWD}/${serverName}/image/remove-source-local.sh"
  if [[ -f "${removeScript}" ]]; then
    echo "[${serverName}] Removing local source image of server: ${serverName} with custom script: ${removeScript}"
    "${removeScript}" &
  else
    "${currentPath}/../../server/image/remove-source-local.sh" -s "${serverName}" &
  fi
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageRemoveSourceLocalScript}" ]]; then
  echo "After image remove source local script: ${afterImageRemoveSourceLocalScript}"
  "${afterImageRemoveSourceLocalScript}"
fi
