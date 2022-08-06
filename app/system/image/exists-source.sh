#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image exists source -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageExistsSourceScript}" ]]; then
  echo "Before image exists source script: ${beforeImageExistsSourceScript}"
  "${beforeImageExistsSourceScript}"
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

  "${currentPath}/../../server/image/exists-source.sh" -s "${serverName}" &
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImageExistsSourceScript}" ]]; then
  echo "After image exists source script: ${afterImageExistsSourceScript}"
  "${afterImageExistsSourceScript}"
fi
