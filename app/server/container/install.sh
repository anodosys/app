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

if [[ -n "${beforeContainerInstallScript}" ]]; then
  echo "Before container install script: ${beforeContainerInstallScript}"
  if [[ -n "${beforeContainerInstallParameters}" ]]; then
    "${beforeContainerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerInstallParameters[@]}"
  else
    "${beforeContainerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerInstallDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container install docker script: ${beforeContainerInstallDockerScript}"
  if [[ -n "${beforeContainerInstallDockerParameters}" ]]; then
    if [[ -n "${beforeContainerInstallDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerInstallDockerUser}" "${beforeContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerInstallDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerInstallDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerInstallDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerInstallDockerUser}" "${beforeContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${beforeContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi

if [[ -n "${containerInstallScript}" ]]; then
  echo "Container install script: ${containerInstallScript}"
  if [[ -n "${containerInstallParameters}" ]]; then
    echo "Container install parameters: ${containerInstallParameters[*]}"
    "${containerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerInstallParameters[@]}"
  else
    "${containerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerInstallDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container install docker script: ${containerInstallDockerScript}"
  if [[ -n "${containerInstallDockerParameters}" ]]; then
    if [[ -n "${containerInstallDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerInstallDockerUser}" "${containerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${containerInstallDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${containerInstallDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerInstallDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerInstallDockerUser}" "${containerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${containerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi

if [[ -n "${containerInstall}" ]]; then
  containerCommand "${containerName}" "${containerInstall}"
fi

if [[ -n "${afterContainerInstallScript}" ]]; then
  echo "After container install script: ${afterContainerInstallScript}"
  if [[ -n "${afterContainerInstallParameters}" ]]; then
    "${afterContainerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerInstallParameters[@]}"
  else
    "${afterContainerInstallScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerInstallDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container install docker script: ${afterContainerInstallDockerScript}"
  if [[ -n "${afterContainerInstallDockerParameters}" ]]; then
    if [[ -n "${afterContainerInstallDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerInstallDockerUser}" "${afterContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerInstallDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerInstallDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerInstallDockerUser}" ]]; then
      containerExecute "${containerName}" "${afterContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${afterContainerInstallDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi
