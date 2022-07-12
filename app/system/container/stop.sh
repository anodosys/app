#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container stop -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerStopScript}" ]]; then
  echo "Before container stop script: ${beforeContainerStopScript}"
  "${beforeContainerStopScript}"
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processedServerNameList

while : ; do
  declare -A processIds
  for serverName in "${serverNames[@]}"; do
    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processedServerNames=$(IFS=,; printf '%s' "${!processedServerNameList[*]}")
      if [[ $("${currentPath}/../../server/container/depends.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        stopScript="${PWD}/${serverName}/container/stop.sh"
        if [[ -f "${stopScript}" ]]; then
          echo "[${serverName}] Stopping container of server: ${serverName} with custom script: ${stopScript}"
          "${stopScript}" &
        else
          "${currentPath}/../../server/container/stop.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerStopScript}" ]]; then
  echo "After container stop script: ${afterContainerStopScript}"
  "${afterContainerStopScript}"
fi
