#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image remove target remote -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageRemoveSourceRemoteScript}" ]]; then
  echo "Before image remove remote script: ${beforeImageRemoveSourceRemoteScript}"
  "${beforeImageRemoveSourceRemoteScript}"
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

  removeScript="${PWD}/${serverName}/image/remove-target-remote.sh"
  if [[ -f "${removeScript}" ]]; then
    echo "[${serverName}] Removing remote target image of server: ${serverName} with custom script: ${removeScript}"
    "${removeScript}" &
  else
    "${currentPath}/../../server/image/remove-target-remote.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageRemoveSourceRemoteScript}" ]]; then
  echo "After image remove remote script: ${afterImageRemoveSourceRemoteScript}"
  "${afterImageRemoveSourceRemoteScript}"
fi
