#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

# create local images
echo "- Image create -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageCreateScript}" ]]; then
  echo "Before image create script: ${beforeImageCreateScript}"
  "${beforeImageCreateScript}"
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

  imageScript="${PWD}/${serverName}/image/create.sh"
  if [[ -f "${imageScript}" ]]; then
    echo "[${serverName}] Creating image of server: ${serverName} with custom script: ${imageScript}"
    "${imageScript}" &
  else
    "${currentPath}/../../server/image/create.sh" -s "${serverName}" &
  fi
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageCreateScript}" ]]; then
  echo "After image create script: ${afterImageCreateScript}"
  "${afterImageCreateScript}"
fi
