#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image exists target -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageExistsTargetRemoteScript}" ]]; then
  echo "Before image exists target remote script: ${beforeImageExistsTargetRemoteScript}"
  "${beforeImageExistsTargetRemoteScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# break if any target image does not exist
declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  "${currentPath}/../../server/image/exists-target-remote.sh" -s "${serverName}" &
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageExistsTargetRemoteScript}" ]]; then
  echo "After image exists target remote script: ${afterImageExistsTargetRemoteScript}"
  "${afterImageExistsTargetRemoteScript}"
fi
