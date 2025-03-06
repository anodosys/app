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

if [[ -n "${beforeContainerStopScript}" ]]; then
  echo "Before container stop script: ${beforeContainerStopScript}"
  if [[ -n "${beforeContainerStopParameters}" ]]; then
    "${beforeContainerStopScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerStopParameters[@]}"
  else
    "${beforeContainerStopScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerStopDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container stop docker script: ${beforeContainerStopDockerScript}"
  if [[ -n "${beforeContainerStopDockerParameters}" ]]; then
    if [[ -n "${beforeContainerStopDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerStopDockerUser}" "${beforeContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerStopDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerStopDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerStopDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerStopDockerUser}" "${beforeContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

containerStop "${containerName}"

if [[ -n "${afterContainerStopScript}" ]]; then
  echo "After container stop script: ${afterContainerStopScript}"
  if [[ -n "${afterContainerStopParameters}" ]]; then
    "${afterContainerStopScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerStopParameters[@]}"
  else
    "${afterContainerStopScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerStopDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container stop docker script: ${afterContainerStopDockerScript}"
  if [[ -n "${afterContainerStopDockerParameters}" ]]; then
    if [[ -n "${afterContainerStopDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerStopDockerUser}" "${afterContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerStopDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerStopDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerStopDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerStopDockerUser}" "${afterContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerStopDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi
