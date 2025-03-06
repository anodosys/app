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

containerName="${systemName}_${serverName}"

if [[ -n "${beforeContainerNotExistsScript}" ]]; then
  echo "Before container not exists script: ${beforeContainerNotExistsScript}"
  if [[ -n "${beforeContainerNotExistsParameters}" ]]; then
    "${beforeContainerNotExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerNotExistsParameters[@]}"
  else
    "${beforeContainerNotExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerNotExistsDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container not exists docker script: ${beforeContainerNotExistsDockerScript}"
  if [[ -n "${beforeContainerNotExistsDockerParameters}" ]]; then
    if [[ -n "${beforeContainerNotExistsDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerNotExistsDockerUser}" "${beforeContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerNotExistsDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerNotExistsDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerNotExistsDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerNotExistsDockerUser}" "${beforeContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ $(containerExists "${containerName}") == 1 ]]; then
  >&2 echo "Container already exists: ${containerName}"
  if [[ "${force}" == 0 ]]; then
    exit 1
  fi
else
  echo "Container does not exist: ${containerName}"
fi

if [[ -n "${afterContainerNotExistsScript}" ]]; then
  echo "After container not exists script: ${afterContainerNotExistsScript}"
  if [[ -n "${afterContainerNotExistsParameters}" ]]; then
    "${afterContainerNotExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerNotExistsParameters[@]}"
  else
    "${afterContainerNotExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerNotExistsDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container not exists docker script: ${afterContainerNotExistsDockerScript}"
  if [[ -n "${afterContainerNotExistsDockerParameters}" ]]; then
    if [[ -n "${afterContainerNotExistsDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerNotExistsDockerUser}" "${afterContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerNotExistsDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerNotExistsDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerNotExistsDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerNotExistsDockerUser}" "${afterContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerNotExistsDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi
