#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container host -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerHostScript}" ]]; then
  echo "Before container host script: ${beforeContainerHostScript}"
  if [[ -n "${beforeContainerHostParameters}" ]]; then
    "${beforeContainerHostScript}" \
      --systemName "${systemName}" \
      "${beforeContainerHostParameters[@]}"
  else
    "${beforeContainerHostScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

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
        hostScript="${PWD}/${serverName}/container/host.sh"
        if [[ -f "${hostScript}" ]]; then
          echo "[${serverName}] Hosting container of server: ${serverName} with custom script: ${hostScript}"
          "${hostScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/host.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerHostScript}" ]]; then
  echo "After container host script: ${afterContainerHostScript}"
  if [[ -n "${afterContainerHostParameters}" ]]; then
    "${afterContainerHostScript}" \
      --systemName "${systemName}" \
      "${afterContainerHostParameters[@]}"
  else
    "${afterContainerHostScript}" \
      --systemName "${systemName}"
  fi
fi
