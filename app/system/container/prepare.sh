#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container prepare -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerPrepareScript}" ]]; then
  echo "Before system container prepare script: ${beforeContainerPrepareScript}"
  if [[ -n "${beforeContainerPrepareParameters}" ]]; then
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}" \
      "${beforeContainerPrepareParameters[@]}"
  else
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  "${currentPath}/../../server/container/path.sh" -s "${serverName}"
done

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
        prepareScript="${PWD}/${serverName}/container/prepare.sh"
        if [[ -f "${prepareScript}" ]]; then
          echo "[${serverName}] Preparing system container of server: ${serverName} with custom script: ${prepareScript}"
          "${prepareScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/prepare.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerPrepareScript}" ]]; then
  echo "After system container prepare script: ${afterContainerPrepareScript}"
  if [[ -n "${afterContainerPrepareParameters}" ]]; then
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}" \
      "${afterContainerPrepareParameters[@]}"
  else
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}"
  fi
fi
