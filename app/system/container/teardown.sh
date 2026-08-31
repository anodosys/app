#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container teardown -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerTeardownScript}" ]]; then
  echo "Before system container teardown script: ${beforeContainerTeardownScript}"
  if [[ -n "${beforeContainerTeardownParameters}" ]]; then
    "${beforeContainerTeardownScript}" \
      --systemName "${systemName}" \
      "${beforeContainerTeardownParameters[@]}"
  else
    "${beforeContainerTeardownScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processedServerNameList

for serverName in "${serverNames[@]}"; do
  containerName="${systemName}_${serverName}"
  if [[ $(containerExists "${containerName}") == 0 ]]; then
    echo "No need to tear down container: ${containerName}"
    processedServerNameList["${serverName}"]=1
  fi
done

while : ; do
  declare -A processIds
  for serverName in "${serverNames[@]}"; do
    if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
      continue
    fi

    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processedServerNames=$(IFS=,; printf '%s' "${!processedServerNameList[*]}")
      if [[ -n "${server}" ]] && [[ "${server}" == "${serverName}" ]] || [[ $("${currentPath}/../../server/container/foundation.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        teardownScript="${PWD}/${serverName}/container/teardown.sh"
        if [[ -f "${teardownScript}" ]]; then
          echo "[${serverName}] Tearing down system container of server: ${serverName} with custom script: ${teardownScript}"
          "${teardownScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/teardown.sh" -s "${serverName}" &
        fi
        processId=$!
        processIds["${serverName}"]="${processId}"
      fi
    fi
  done

  for serverName in "${!processIds[@]}"; do
    if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
      continue
    fi

    processId="${processIds[${serverName}]}"
    wait "${processId}"
    processedServerNameList["${serverName}"]=1
  done

  processed=1
  for serverName in "${serverNames[@]}"; do
    if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
      continue
    fi

    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processed=0
      break
    fi
  done

  if [[ "${processed}" == 1 ]]; then
    break
  fi
done

if [[ -n "${afterContainerTeardownScript}" ]]; then
  echo "After system container teardown script: ${afterContainerTeardownScript}"
  if [[ -n "${afterContainerTeardownParameters}" ]]; then
    "${afterContainerTeardownScript}" \
      --systemName "${systemName}" \
      "${afterContainerTeardownParameters[@]}"
  else
    "${afterContainerTeardownScript}" \
      --systemName "${systemName}"
  fi
fi
