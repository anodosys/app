#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image prepare container -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImagePrepareContainerScript}" ]]; then
  echo "Before image prepare container script: ${beforeImagePrepareContainerScript}"
  "${beforeImagePrepareContainerScript}" \
    --systemName "${systemName}"
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

  imageScript="${PWD}/${serverName}/image/prepare-container.sh"
  if [[ -f "${imageScript}" ]]; then
    echo "[${serverName}] Prepare containter to create image of server: ${serverName} with custom script: ${imageScript}"
    "${imageScript}" &
  else
    "${currentPath}/../../server/image/prepare-container.sh" -s "${serverName}" &
  fi
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImagePrepareContainerScript}" ]]; then
  echo "After image prepare container script: ${afterImagePrepareContainerScript}"
  "${afterImagePrepareContainerScript}" \
    --systemName "${systemName}"
fi
