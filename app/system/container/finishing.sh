#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container finishing -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -f "${anodosysUserVarPath}/finisihing/${systemName}" ]]; then
  echo "Finishing already processed"
  exit 0
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerFinishingScript}" ]]; then
  echo "Before container finishing script: ${beforeContainerFinishingScript}"
  if [[ -n "${beforeContainerFinishingParameters}" ]]; then
    "${beforeContainerFinishingScript}" "${beforeContainerFinishingParameters[@]}"
  else
    "${beforeContainerFinishingScript}"
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
        finishingScript="${PWD}/${serverName}/container/finishing.sh"
        if [[ -f "${finishingScript}" ]]; then
          echo "[${serverName}] Finishing container of server: ${serverName} with custom script: ${finishingScript}"
          "${finishingScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/finishing.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerFinishingScript}" ]]; then
  echo "After container finishing script: ${afterContainerFinishingScript}"
  if [[ -n "${afterContainerFinishingParameters}" ]]; then
    "${afterContainerFinishingScript}" "${afterContainerFinishingParameters[@]}"
  else
    "${afterContainerFinishingScript}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/finisihing"
touch "${anodosysUserVarPath}/finisihing/${systemName}"
