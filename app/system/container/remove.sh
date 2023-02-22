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

echo "- Container remove -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerRemoveScript}" ]]; then
  echo "Before container remove script: ${beforeContainerRemoveScript}"
  "${beforeContainerRemoveScript}"
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processedServerNameList

for serverName in "${serverNames[@]}"; do
  containerName="${systemName}_${serverName}"
  if [[ $(containerExists "${containerName}") == 0 ]]; then
    echo "No need to remove container: ${containerName}"
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
      if [[ $("${currentPath}/../../server/container/foundation.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        removeScript="${PWD}/${serverName}/container/remove.sh"
        if [[ -f "${removeScript}" ]]; then
          echo "[${serverName}] Removing container of server: ${serverName} with custom script: ${removeScript}"
          "${removeScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/remove.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerRemoveScript}" ]]; then
  echo "After container remove script: ${afterContainerRemoveScript}"
  "${afterContainerRemoveScript}"
fi

mkdir -p "${anodosysUserVarPath}/commencement"
rm -rf "${anodosysUserVarPath}/commencement/${systemName}"
mkdir -p "${anodosysUserVarPath}/production"
rm -rf "${anodosysUserVarPath}/production/${systemName}"
mkdir -p "${anodosysUserVarPath}/finishing"
rm -rf "${anodosysUserVarPath}/finishing/${systemName}"
