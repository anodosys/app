#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No anodosys user var configuration path defined!"
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

if [[ -n "${priorContainerPrepareScript}" ]]; then
  echo "Prior container prepare script: ${priorContainerPrepareScript}"
  if [[ -n "${priorContainerPrepareParameters}" ]]; then
    "${priorContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${priorContainerPrepareParameters[@]}"
  else
    "${priorContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${priorContainerPrepareDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Prior container prepare docker script: ${priorContainerPrepareDockerScript}"
  if [[ -n "${priorContainerPrepareDockerParameters}" ]]; then
    if [[ -n "${priorContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerPrepareDockerUser}" "${priorContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerPrepareDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${priorContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${priorContainerPrepareDockerParameters[@]}"
    fi
  else
    if [[ -n "${priorContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${priorContainerPrepareDockerUser}" "${priorContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${priorContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${beforeContainerPrepareScript}" ]]; then
  echo "Before container prepare script: ${beforeContainerPrepareScript}"
  if [[ -n "${beforeContainerPrepareParameters}" ]]; then
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerPrepareParameters[@]}"
  else
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerPrepareDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container prepare docker script: ${beforeContainerPrepareDockerScript}"
  if [[ -n "${beforeContainerPrepareDockerParameters}" ]]; then
    if [[ -n "${beforeContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerPrepareDockerUser}" "${beforeContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerPrepareDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${beforeContainerPrepareDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerPrepareDockerUser}" "${beforeContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${beforeContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"
containerCopy "${containerName}" "${configurationFile}" "/container.sh"

if [[ -n "${containerPrepareFiles}" ]]; then
  for containerPrepareFile in "${containerPrepareFiles[@]}"; do
    containerCopy "${containerName}" "${containerPrepareFile}"
  done
fi

if [[ -n "${containerPrepareScript}" ]]; then
  echo "Container prepare script: ${containerPrepareScript}"
  if [[ -n "${containerPrepareParameters}" ]]; then
    "${containerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerPrepareParameters[@]}"
  else
    "${containerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerPrepareDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container prepare docker script: ${containerPrepareDockerScript}"
  if [[ -n "${containerPrepareDockerParameters}" ]]; then
    if [[ -n "${containerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerPrepareDockerUser}" "${containerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerPrepareDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${containerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${containerPrepareDockerParameters[@]}"
    fi
  else
    if [[ -n "${containerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${containerPrepareDockerUser}" "${containerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${containerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${containerPrepare}" ]]; then
  containerCommand "${containerName}" "${containerPrepare}"
fi

if [[ -n "${afterContainerPrepareScript}" ]]; then
  echo "After container prepare script: ${afterContainerPrepareScript}"
  if [[ -n "${afterContainerPrepareParameters}" ]]; then
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerPrepareParameters[@]}"
  else
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerPrepareDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container prepare docker script: ${afterContainerPrepareDockerScript}"
  if [[ -n "${afterContainerPrepareDockerParameters}" ]]; then
    if [[ -n "${afterContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerPrepareDockerUser}" "${afterContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerPrepareDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${afterContainerPrepareDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerPrepareDockerUser}" "${afterContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${afterContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi

if [[ -n "${postContainerPrepareScript}" ]]; then
  echo "Post container prepare script: ${postContainerPrepareScript}"
  if [[ -n "${postContainerPrepareParameters}" ]]; then
    "${postContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${postContainerPrepareParameters[@]}"
  else
    "${postContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${postContainerPrepareDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Post container prepare docker script: ${postContainerPrepareDockerScript}"
  if [[ -n "${postContainerPrepareDockerParameters}" ]]; then
    if [[ -n "${postContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerPrepareDockerUser}" "${postContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerPrepareDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${postContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}" \
        "${postContainerPrepareDockerParameters[@]}"
    fi
  else
    if [[ -n "${postContainerPrepareDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${postContainerPrepareDockerUser}" "${postContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    else
      containerExecute "${containerName}" "${postContainerPrepareDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        --hostGroupId "${GID}"
    fi
  fi
fi
