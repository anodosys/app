#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image exists source -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageExistsSourceRemoteScript}" ]]; then
  echo "Before image exists source remote script: ${beforeImageExistsSourceRemoteScript}"
  "${beforeImageExistsSourceRemoteScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# break if any source image does not exist
declare -A processIds
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  "${currentPath}/../../server/image/exists-source-remote.sh" -s "${serverName}" &
  processId=$!
  processIds["${serverName}"]="${processId}"
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageExistsSourceRemoteScript}" ]]; then
  echo "After image exists source remote script: ${afterImageExistsSourceRemoteScript}"
  "${afterImageExistsSourceRemoteScript}"
fi
