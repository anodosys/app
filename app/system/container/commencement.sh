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

echo "- Container commencement -" | sed $'s,.*,\e[1;37m&\e[m,'

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  "${currentPath}/../../server/container/path.sh" -s "${serverName}"
done

if [[ -f "${anodosysUserVarPath}/commencement/${systemName}" ]]; then
  echo "Commencement already processed"
  exit 0
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerCommencementScript}" ]]; then
  echo "Before container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${beforeContainerCommencementParameters}" ]]; then
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}" \
      "${beforeContainerCommencementParameters[@]}"
  else
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}"
  fi
fi

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
        commencementScript="${PWD}/${serverName}/container/commencement.sh"
        if [[ -f "${commencementScript}" ]]; then
          echo "[${serverName}] Commencement container of server: ${serverName} with custom script: ${commencementScript}"
          "${commencementScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/commencement.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerCommencementScript}" ]]; then
  echo "After container commencement script: ${afterContainerCommencementScript}"
  if [[ -n "${afterContainerCommencementParameters}" ]]; then
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}" \
      "${afterContainerCommencementParameters[@]}"
  else
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/commencement"
touch "${anodosysUserVarPath}/commencement/${systemName}"
