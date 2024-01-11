#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${systemPath}" ]]; then
  >&2 echo "No system path specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Container install -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerInstallScript}" ]]; then
  echo "Before container install script: ${beforeContainerInstallScript}"
  if [[ -n "${beforeContainerInstallParameters}" ]]; then
    "${beforeContainerInstallScript}" \
      --systemName "${systemName}" \
      "${beforeContainerInstallParameters[@]}"
  else
    "${beforeContainerInstallScript}" \
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
        installScript="${systemPath}/${serverName}/container/install.sh"
        if [[ -f "${installScript}" ]]; then
          echo "[${serverName}] Installing container of server: ${serverName} with custom script: ${installScript}"
          "${installScript}" -s "${serverName}" &
        else
          "${currentPath}/../../server/container/install.sh" -s "${serverName}" &
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

if [[ -n "${afterContainerInstallScript}" ]]; then
  echo "After container install script: ${afterContainerInstallScript}"
  if [[ -n "${afterContainerInstallParameters}" ]]; then
    "${afterContainerInstallScript}" \
      --systemName "${systemName}" \
      "${afterContainerInstallParameters[@]}"
  else
    "${afterContainerInstallScript}" \
      --systemName "${systemName}"
  fi
fi
