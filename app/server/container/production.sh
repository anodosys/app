#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
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

containerName="${systemName}_${serverName}"

if [[ -f "${anodosysUserVarPath}/production/${containerName}" ]]; then
  echo "Production already processed"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${priorContainerProductionScript}" ]]; then
  echo "Prior container production script: ${priorContainerProductionScript}"
  if [[ -n "${priorContainerProductionParameters}" ]]; then
    "${priorContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${priorContainerProductionParameters[@]}"
  else
    "${priorContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${priorContainerProductionDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Prior container production docker script: ${priorContainerProductionDockerScript}"
  if [[ -n "${priorContainerProductionDockerParameters}" ]]; then
    if [[ -n "${priorContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerProductionDockerUser}" "${priorContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerProductionDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${priorContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerProductionDockerParameters[@]}"
    fi
  else
    if [[ -n "${priorContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerProductionDockerUser}" "${priorContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${priorContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${beforeContainerProductionScript}" ]]; then
  echo "Before container production script: ${beforeContainerProductionScript}"
  if [[ -n "${beforeContainerProductionParameters}" ]]; then
    "${beforeContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerProductionParameters[@]}"
  else
    "${beforeContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerProductionDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container production docker script: ${beforeContainerProductionDockerScript}"
  if [[ -n "${beforeContainerProductionDockerParameters}" ]]; then
    if [[ -n "${beforeContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerProductionDockerUser}" "${beforeContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerProductionDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerProductionDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerProductionDockerUser}" "${beforeContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerProductionScript}" ]]; then
  echo "Container production script: ${containerProductionScript}"
  if [[ -n "${containerProductionParameters}" ]]; then
    "${containerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerProductionParameters[@]}"
  else
    "${containerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerProductionDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container production docker script: ${containerProductionDockerScript}"
  if [[ -n "${containerProductionDockerParameters}" ]]; then
    if [[ -n "${containerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerProductionDockerUser}" "${containerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerProductionDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerProductionDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerProductionDockerUser}" "${containerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${containerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerProduction}" ]]; then
  containerCommand "${containerName}" "${containerProduction}"
fi

if [[ -n "${afterContainerProductionScript}" ]]; then
  echo "After container production script: ${afterContainerProductionScript}"
  if [[ -n "${afterContainerProductionParameters}" ]]; then
    "${afterContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerProductionParameters[@]}"
  else
    "${afterContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerProductionDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container production docker script: ${afterContainerProductionDockerScript}"
  if [[ -n "${afterContainerProductionDockerParameters}" ]]; then
    if [[ -n "${afterContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerProductionDockerUser}" "${afterContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerProductionDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerProductionDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerProductionDockerUser}" "${afterContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${postContainerProductionScript}" ]]; then
  echo "Post container production script: ${postContainerProductionScript}"
  if [[ -n "${postContainerProductionParameters}" ]]; then
    "${postContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${postContainerProductionParameters[@]}"
  else
    "${postContainerProductionScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${postContainerProductionDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Post container production docker script: ${postContainerProductionDockerScript}"
  if [[ -n "${postContainerProductionDockerParameters}" ]]; then
    if [[ -n "${postContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerProductionDockerUser}" "${postContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerProductionDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${postContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerProductionDockerParameters[@]}"
    fi
  else
    if [[ -n "${postContainerProductionDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerProductionDockerUser}" "${postContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${postContainerProductionDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

mkdir -p "${anodosysUserVarPath}/production"
touch "${anodosysUserVarPath}/production/${containerName}"
