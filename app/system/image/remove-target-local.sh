#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image remove target local -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageRemoveTargetLocalScript}" ]]; then
  echo "Before image remove target local script: ${beforeImageRemoveTargetLocalScript}"
  "${beforeImageRemoveTargetLocalScript}"
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

  removeScript="${PWD}/${serverName}/image/remove-target-local.sh"
  if [[ -f "${removeScript}" ]]; then
    echo "[${serverName}] Removing local target image of server: ${serverName} with custom script: ${removeScript}"
    "${removeScript}" &
  else
    "${currentPath}/../../server/image/remove-target-local.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageRemoveTargetLocalScript}" ]]; then
  echo "After image remove target local script: ${afterImageRemoveTargetLocalScript}"
  "${afterImageRemoveTargetLocalScript}"
fi
