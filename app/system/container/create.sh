#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Use source image
  -t  Use target image

Example: ${scriptName} -s
EOF
}

trim()
{
  echo -n "$1" | xargs
}

useSourceImage=0
useTargetImage=0

while getopts hst? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) useSourceImage=1;;
    t) useTargetImage=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ "${useSourceImage}" == 0 ]] && [[ "${useTargetImage}" == 0 ]]; then
  >&2 echo "Please specifiy which image to use"
  usage
  exit 1
fi

if [[ "${useSourceImage}" == 1 ]]; then
  imageSource="source"
else
  imageSource="target"
fi

setServerConfiguration "${systemName}" "system"

echo "- Container create -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerCreateScript}" ]]; then
  echo "Before container create script: ${beforeContainerCreateScript}"
  "${beforeContainerCreateScript}"
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processedServerNameList

while : ; do
  declare -A processIds
  for serverName in "${serverNames[@]}"; do
    if ! test "${processedServerNameList["${serverName}"]+isset}"; then
      processedServerNames=$(IFS=,; printf '%s' "${!processedServerNameList[*]}")
      if [[ $("${currentPath}/../../server/container/depends.sh" -s "${serverName}" -p "${processedServerNames}") == 1 ]]; then
        createScript="${PWD}/${serverName}/container/${imageSource}/create.sh"
        if [[ -f "${createScript}" ]]; then
          echo "[${serverName}] Creating container of server: ${serverName} with custom script: ${createScript}"
          "${createScript}" &
        else
          "${currentPath}/../../server/container/create.sh" -s "${serverName}" -i "${imageSource}" &
        fi
        processIds["${serverName}"]=$!
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

if [[ -n "${afterContainerCreateScript}" ]]; then
  echo "After container create script: ${afterContainerCreateScript}"
  "${afterContainerCreateScript}"
fi
