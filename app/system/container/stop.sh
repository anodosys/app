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

declare -A supportsServerNameList

for serverName in "${serverNames[@]}"; do
  dependList=( $("${currentPath}/../../server/container/depends.sh" -s "${serverName}") )
  for dependServerName in "${dependList[@]}"; do
    if ! test "${supportsServerNameList["${dependServerName}"]+isset}"; then
      supportsServerNameList["${dependServerName}"]="${serverName}"
    else
      supportsServerNameList["${dependServerName}"]+=",${serverName}"
    fi
  done
done

declare -A processedServerNameList

while : ; do
  declare -A processIds
  runningServerNameList=()
  for serverName in "${serverNames[@]}"; do
    containerName="${systemName}_${serverName}"
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      runningServerNameList+=("${serverName}")
    fi
  done
  runningServerNames=$(IFS=,; printf '%s' "${runningServerNameList[*]}")
  if [[ -z "${runningServerNames}" ]]; then
    runningServerNames="none"
  fi
  for serverName in "${serverNames[@]}"; do
    if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
      continue
    fi

    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      if test "${supportsServerNameList["${serverName}"]+isset}"; then
        supportsServerNames=${supportsServerNameList[${serverName}]}
      else
        supportsServerNames="none"
      fi
      if [[ $("${currentPath}/../../server/container/independent.sh" -s "${serverName}" -p "${supportsServerNames}" -r "${runningServerNames}") == 1 ]]; then
        stopScript="${PWD}/${serverName}/container/stop.sh"
        if [[ -f "${stopScript}" ]]; then
          echo "[${serverName}] Stopping container of server: ${serverName} with custom script: ${stopScript}"
          "${stopScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/stop.sh" -s "${serverName}" &
        fi
        processId=$!
        processIds["${serverName}"]="${processId}"
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
