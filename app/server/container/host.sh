#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=

while getopts hs:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

logName "${systemName}" "${serverName}"

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -n "${beforeContainerHostScript}" ]]; then
  echo "Before container host script: ${beforeContainerHostScript}"
  if [[ -n "${beforeContainerHostParameters}" ]]; then
    "${beforeContainerHostScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerHostParameters[@]}"
  else
    "${beforeContainerHostScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerHostDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container host docker script: ${beforeContainerHostDockerScript}"
  if [[ -n "${beforeContainerHostDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerHostDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${beforeContainerHostDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerHostDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

echo "Checking if ports are blocked for container: ${containerName}"
if [[ $(containerPortBlocked "${containerName}") == 1 ]]; then
  >&2 echo "Cannot start container because ports are blocked"
  exit 1
fi

if [[ -z "${containerVolumes}" ]]; then
  containerVolumes=()
fi

if [[ "${#containerVolumes[@]}" -gt 0 ]]; then
  echo "Checking volumes for container: ${containerName}"

  success=1

  for containerVolume in "${containerVolumes[@]}"; do
    readarray -d : -t parameterParts < <(printf '%s' "${containerVolume}")
    sourcePath="${parameterParts[0]}"
    targetUser=$(getArrayValue 2 "me" "${parameterParts[@]}")
    mode=$(getArrayValue 3 "r" "${parameterParts[@]}")

    checkResult=$(containerVolumeCheckSourcePath "${sourcePath}" "${targetUser}" "${mode}")
    if [[ "${checkResult}" != "success" ]]; then
      success=0
    fi
  done

  if [[ "${success}" == 0 ]]; then
    exit 1
  fi
else
  echo "No volumes to check for container: ${containerName}"
fi

if [[ -n "${afterContainerHostScript}" ]]; then
  echo "After container host script: ${afterContainerHostScript}"
  if [[ -n "${afterContainerHostParameters}" ]]; then
    "${afterContainerHostScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerHostParameters[@]}"
  else
    "${afterContainerHostScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerHostDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container host docker script: ${afterContainerHostDockerScript}"
  if [[ -n "${afterContainerHostDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerHostDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${afterContainerHostDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerHostDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi
