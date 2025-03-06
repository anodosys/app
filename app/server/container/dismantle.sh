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

if [[ -n "${beforeContainerDismantleScript}" ]]; then
  echo "Before container dismantle script: ${beforeContainerDismantleScript}"
  if [[ -n "${beforeContainerDismantleParameters}" ]]; then
    "${beforeContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerDismantleParameters[@]}"
  else
    "${beforeContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerDismantleDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container dismantle docker script: ${beforeContainerDismantleDockerScript}"
  if [[ -n "${beforeContainerDismantleDockerParameters}" ]]; then
    if [[ -n "${beforeContainerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerDismantleDockerUser}" "${beforeContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerDismantleDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerDismantleDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerDismantleDockerUser}" "${beforeContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerDismantleScript}" ]]; then
  echo "Container dismantle script: ${containerDismantleScript}"
  if [[ -n "${containerDismantleParameters}" ]]; then
    "${containerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerDismantleParameters[@]}"
  else
    "${containerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerDismantleDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container dismantle docker script: ${containerDismantleDockerScript}"
  if [[ -n "${containerDismantleDockerParameters}" ]]; then
    if [[ -n "${containerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerDismantleDockerUser}" "${containerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerDismantleDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerDismantleDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerDismantleDockerUser}" "${containerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${containerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerDismantle}" ]]; then
  containerCommand "${containerName}" "${containerDismantle}"
fi

if [[ -n "${afterContainerDismantleScript}" ]]; then
  echo "After container dismantle script: ${afterContainerDismantleScript}"
  if [[ -n "${afterContainerDismantleParameters}" ]]; then
    "${afterContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerDismantleParameters[@]}"
  else
    "${afterContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerDismantleDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container dismantle docker script: ${afterContainerDismantleDockerScript}"
  if [[ -n "${afterContainerDismantleDockerParameters}" ]]; then
    if [[ -n "${afterContainerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerDismantleDockerUser}" "${afterContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerDismantleDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerDismantleDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerDismantleDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerDismantleDockerUser}" "${afterContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerDismantleDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi
