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

if [[ -f "${anodosysUserVarPath}/finishing/${containerName}" ]]; then
  echo "Finishing already processed"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${priorContainerFinishingScript}" ]]; then
  echo "Prior container finishing script: ${priorContainerFinishingScript}"
  if [[ -n "${priorContainerFinishingParameters}" ]]; then
    "${priorContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${priorContainerFinishingParameters[@]}"
  else
    "${priorContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${priorContainerFinishingDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Prior container finishing docker script: ${priorContainerFinishingDockerScript}"
  if [[ -n "${priorContainerFinishingDockerParameters}" ]]; then
    if [[ -n "${priorContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerFinishingDockerUser}" "${priorContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerFinishingDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${priorContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerFinishingDockerParameters[@]}"
    fi
  else
    if [[ -n "${priorContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerFinishingDockerUser}" "${priorContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${priorContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${beforeContainerFinishingScript}" ]]; then
  echo "Before container finishing script: ${beforeContainerFinishingScript}"
  if [[ -n "${beforeContainerFinishingParameters}" ]]; then
    "${beforeContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerFinishingParameters[@]}"
  else
    "${beforeContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerFinishingDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container finishing docker script: ${beforeContainerFinishingDockerScript}"
  if [[ -n "${beforeContainerFinishingDockerParameters}" ]]; then
    if [[ -n "${beforeContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerFinishingDockerUser}" "${beforeContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerFinishingDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerFinishingDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerFinishingDockerUser}" "${beforeContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerFinishingScript}" ]]; then
  echo "Container finishing docker script: ${containerFinishingScript}"
  if [[ -n "${containerFinishingParameters}" ]]; then
    "${containerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerFinishingParameters[@]}"
  else
    "${containerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerFinishingDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container finishing docker script: ${containerFinishingDockerScript}"
  if [[ -n "${containerFinishingDockerParameters}" ]]; then
    if [[ -n "${containerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerFinishingDockerUser}" "${containerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerFinishingDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerFinishingDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerFinishingDockerUser}" "${containerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${containerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerFinishing}" ]]; then
  containerCommand "${containerName}" "${containerFinishing}"
fi

if [[ -n "${afterContainerFinishingScript}" ]]; then
  echo "After container finishing script: ${afterContainerFinishingScript}"
  if [[ -n "${afterContainerFinishingParameters}" ]]; then
    "${afterContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerFinishingParameters[@]}"
  else
    "${afterContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerFinishingDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container finishing docker script: ${afterContainerFinishingDockerScript}"
  if [[ -n "${afterContainerFinishingDockerParameters}" ]]; then
    if [[ -n "${afterContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerFinishingDockerUser}" "${afterContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerFinishingDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerFinishingDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerFinishingDockerUser}" "${afterContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${postContainerFinishingScript}" ]]; then
  echo "Post container finishing script: ${postContainerFinishingScript}"
  if [[ -n "${postContainerFinishingParameters}" ]]; then
    "${postContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${postContainerFinishingParameters[@]}"
  else
    "${postContainerFinishingScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${postContainerFinishingDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Post container finishing docker script: ${postContainerFinishingDockerScript}"
  if [[ -n "${postContainerFinishingDockerParameters}" ]]; then
    if [[ -n "${postContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerFinishingDockerUser}" "${postContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerFinishingDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${postContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerFinishingDockerParameters[@]}"
    fi
  else
    if [[ -n "${postContainerFinishingDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerFinishingDockerUser}" "${postContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${postContainerFinishingDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

mkdir -p "${anodosysUserVarPath}/finishing"
touch "${anodosysUserVarPath}/finishing/${containerName}"
