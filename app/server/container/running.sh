#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${force}" ]]; then
  >&2 echo "No force status specified!"
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

if [[ -n "${beforeContainerRunningScript}" ]]; then
  echo "Before container running script: ${beforeContainerRunningScript}"
  if [[ -n "${beforeContainerRunningParameters}" ]]; then
    "${beforeContainerRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerRunningParameters[@]}"
  else
    "${beforeContainerRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerRunningDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container running docker script: ${beforeContainerRunningDockerScript}"
  if [[ -n "${beforeContainerRunningDockerParameters}" ]]; then
    if [[ -n "${beforeContainerRunningDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerRunningDockerUser}" "${beforeContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerRunningDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerRunningDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerRunningDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerRunningDockerUser}" "${beforeContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${beforeContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  echo "Image requires interactive run"
  exit 0
fi

containerName="${systemName}_${serverName}"

if [[ $(containerRunning "${containerName}") == 0 ]]; then
  >&2 echo "Container not running: ${containerName}"
  if [[ "${force}" == 0 ]]; then
    exit 1
  fi
else
  echo "Container running: ${containerName}"
fi

if [[ -n "${afterContainerRunningScript}" ]]; then
  echo "After container running script: ${afterContainerRunningScript}"
  if [[ -n "${afterContainerRunningParameters}" ]]; then
    "${afterContainerRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerRunningParameters[@]}"
  else
    "${afterContainerRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerRunningDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container running docker script: ${afterContainerRunningDockerScript}"
  if [[ -n "${afterContainerRunningDockerParameters}" ]]; then
    if [[ -n "${afterContainerRunningDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerRunningDockerUser}" "${afterContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerRunningDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerRunningDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerRunningDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerRunningDockerUser}" "${afterContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${afterContainerRunningDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi
