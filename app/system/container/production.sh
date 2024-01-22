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

echo "- Container production -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -f "${anodosysUserVarPath}/production/${systemName}" ]]; then
  echo "Production already processed"
  exit 0
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerProductionScript}" ]]; then
  echo "Before container production script: ${beforeContainerProductionScript}"
  if [[ -n "${beforeContainerProductionParameters}" ]]; then
    "${beforeContainerProductionScript}" \
      --systemName "${systemName}" \
      "${beforeContainerProductionParameters[@]}"
  else
    "${beforeContainerProductionScript}" \
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
      if [[ -n "${server}" ]] && [[ "${server}" == "${serverName}" ]] || [[ $("${currentPath}/../../server/container/foundation.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        productionScript="${PWD}/${serverName}/container/production.sh"
        if [[ -f "${productionScript}" ]]; then
          echo "[${serverName}] Production container of server: ${serverName} with custom script: ${productionScript}"
          "${productionScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/production.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerProductionScript}" ]]; then
  echo "After container production script: ${afterContainerProductionScript}"
  if [[ -n "${afterContainerProductionParameters}" ]]; then
    "${afterContainerProductionScript}" \
      --systemName "${systemName}" \
      "${afterContainerProductionParameters[@]}"
  else
    "${afterContainerProductionScript}" \
      --systemName "${systemName}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/production"
touch "${anodosysUserVarPath}/production/${systemName}"
