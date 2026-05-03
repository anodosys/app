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

if [[ -n "${beforeContainerTeardownScript}" ]]; then
  echo "Before container teardown script: ${beforeContainerTeardownScript}"
  if [[ -n "${beforeContainerTeardownParameters}" ]]; then
    "${beforeContainerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerTeardownParameters[@]}"
  else
    "${beforeContainerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerTeardownDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container teardown docker script: ${beforeContainerTeardownDockerScript}"
  if [[ -n "${beforeContainerTeardownDockerParameters}" ]]; then
    if [[ -n "${beforeContainerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerTeardownDockerUser}" "${beforeContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerTeardownDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerTeardownDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerTeardownDockerUser}" "${beforeContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerTeardownScript}" ]]; then
  echo "Container teardown script: ${containerTeardownScript}"
  if [[ -n "${containerTeardownParameters}" ]]; then
    "${containerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerTeardownParameters[@]}"
  else
    "${containerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerTeardownDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container teardown docker script: ${containerTeardownDockerScript}"
  if [[ -n "${containerTeardownDockerParameters}" ]]; then
    if [[ -n "${containerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerTeardownDockerUser}" "${containerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerTeardownDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerTeardownDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerTeardownDockerUser}" "${containerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${containerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerTeardown}" ]]; then
  containerCommand "${containerName}" "${containerTeardown}"
fi

if [[ -n "${afterContainerTeardownScript}" ]]; then
  echo "After container teardown script: ${afterContainerTeardownScript}"
  if [[ -n "${afterContainerTeardownParameters}" ]]; then
    "${afterContainerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerTeardownParameters[@]}"
  else
    "${afterContainerTeardownScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerTeardownDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container teardown docker script: ${afterContainerTeardownDockerScript}"
  if [[ -n "${afterContainerTeardownDockerParameters}" ]]; then
    if [[ -n "${afterContainerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerTeardownDockerUser}" "${afterContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerTeardownDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerTeardownDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerTeardownDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerTeardownDockerUser}" "${afterContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerTeardownDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi
