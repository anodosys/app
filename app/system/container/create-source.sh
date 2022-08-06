#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container create source -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerCreateSourceScript}" ]]; then
  echo "Before container create source script: ${beforeContainerCreateSourceScript}"
  "${beforeContainerCreateSourceScript}"
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# creates the containers from the source image
declare -A processedServerNameList
while : ; do
  declare -A processIds
  for serverName in "${serverNames[@]}"; do
    if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
      continue
    fi

    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processedServerNames=$(IFS=,; printf '%s' "${!processedServerNameList[*]}")
      if [[ $("${currentPath}/../../server/container/foundation.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        createScript="${PWD}/${serverName}/container/create-source.sh"
        if [[ -f "${createScript}" ]]; then
          echo "[${serverName}] Creating container of server: ${serverName} with custom script: ${createScript}"
          "${createScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/create-source.sh" -s "${serverName}" &
        fi
        processIds["${serverName}"]=$!
      fi
    fi
  done

  for serverName in "${!processIds[@]}"; do
    processId="${processIds[${serverName}]}"
    wait "${processId}"
    processedServerNameList["${serverName}"]=1
  done

  processed=1
  for serverName in "${serverNames[@]}"; do
    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processed=0
      break
    fi
  done

  if [[ "${processed}" == 1 ]]; then
    break
  fi
done

if [[ -n "${afterContainerCreateSourceScript}" ]]; then
  echo "After container create source script: ${afterContainerCreateSourceScript}"
  "${afterContainerCreateSourceScript}"
fi
