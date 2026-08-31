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

echo "- Container create target -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerCreateTargetScript}" ]]; then
  echo "Before system container create target script: ${beforeContainerCreateTargetScript}"
  if [[ -n "${beforeContainerCreateTargetParameters}" ]]; then
    "${beforeContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      "${beforeContainerCreateTargetParameters[@]}"
  else
    "${beforeContainerCreateTargetScript}" \
      --systemName "${systemName}"
  fi
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# creates the containers from the target image
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
        createScript="${PWD}/${serverName}/container/create-target.sh"
        if [[ -f "${createScript}" ]]; then
          echo "[${serverName}] Creating system container of server: ${serverName} with custom script: ${createScript}"
          "${createScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/create-target.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerCreateTargetScript}" ]]; then
  echo "After system container create target script: ${afterContainerCreateTargetScript}"
  if [[ -n "${afterContainerCreateTargetParameters}" ]]; then
    "${afterContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      "${afterContainerCreateTargetParameters[@]}"
  else
    "${afterContainerCreateTargetScript}" \
      --systemName "${systemName}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/commencement"
rm -rf "${anodosysUserVarPath}/commencement/${systemName}"
mkdir -p "${anodosysUserVarPath}/production"
rm -rf "${anodosysUserVarPath}/production/${systemName}"
mkdir -p "${anodosysUserVarPath}/finishing"
rm -rf "${anodosysUserVarPath}/finishing/${systemName}"
