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

if [[ -z "${useNamedVolumes}" ]]; then
  useNamedVolumes="false"
fi

if [[ -n "${beforeContainerStartScript}" ]]; then
  echo "Before container start script: ${beforeContainerStartScript}"
  if [[ -n "${beforeContainerStartParameters}" ]]; then
    "${beforeContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerStartParameters[@]}"
  else
    "${beforeContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerStartDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container start docker script: ${beforeContainerStartDockerScript}"
  if [[ -n "${beforeContainerStartDockerParameters}" ]]; then
    if [[ -n "${beforeContainerStartDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerStartDockerUser}" "${beforeContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerStartDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${beforeContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${beforeContainerStartDockerParameters[@]}"
    fi
  else
    if [[ -n "${beforeContainerStartDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${beforeContainerStartDockerUser}" "${beforeContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${beforeContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi

optionalParameters=( )

if [[ -n "${imageEntryPoint}" ]]; then
  optionalParameters+=( "entryPoint:${imageEntryPoint}" )
fi

optionalParameters+=( "alias:${serverName}" )

if [[ -z "${containerAliases}" ]]; then
  containerAliases=()
fi

for containerAlias in "${containerAliases[@]}"; do
  optionalParameters+=( "alias:${containerAlias}" )
done

if [[ -z "${containerPorts}" ]]; then
  containerPorts=()
fi

for containerPort in "${containerPorts[@]}"; do
  optionalParameters+=( "port:${containerPort}" )
done

if [[ -z "${containerExpose}" ]]; then
  containerExpose=()
fi

for nextContainerExpose in "${containerExpose[@]}"; do
  optionalParameters+=( "expose:${nextContainerExpose}" )
done

if [[ -z "${containerVolumes}" ]]; then
  containerVolumes=()
fi

for containerVolume in "${containerVolumes[@]}"; do
  optionalParameters+=( "volume:${containerVolume}" )
done

if [[ -z "${containerVariables}" ]]; then
  containerVariables=()
fi

for containerVariable in "${containerVariables[@]}"; do
  optionalParameters+=( "environment:${containerVariable}" )
done

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  if [[ $(containerExists "${containerName}") == 0 ]]; then
    echo "Image requires interactive run"

    if [[ -z "${imageName}" ]]; then
      >&2 echo "No source image name for server: ${serverName}"
      exit 1
    fi
    if [[ -z "${imageTag}" ]]; then
      >&2 echo "No source image tag for server: ${serverName}"
      exit 1
    fi

    if [[ -n "${imageInteractiveCommand}" ]]; then
    echo "Running image with command: ${imageInteractiveCommand}"
      containerRun "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "${imageInteractiveCommand}" "${optionalParameters[@]}"
    else
      containerRun "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "-" "${optionalParameters[@]}"
    fi

    exit 0
  fi
fi

if [[ -z "${skipPortsAvailable}" ]]; then
  skipPortsAvailable="false"
fi

if [[ -z "${follow}" ]]; then
  follow="false"
fi

containerStart "${containerName}" "${useNamedVolumes}" no "${skipPortsAvailable}" "${follow}"

if [[ -n "${afterContainerStartScript}" ]]; then
  echo "After container start script: ${afterContainerStartScript}"
  if [[ -n "${afterContainerStartParameters}" ]]; then
    "${afterContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerStartParameters[@]}"
  else
    "${afterContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerStartDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container start docker script: ${afterContainerStartDockerScript}"
  if [[ -n "${afterContainerStartDockerParameters}" ]]; then
    if [[ -n "${afterContainerStartDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerStartDockerUser}" "${afterContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerStartDockerParameters[@]}"
    else
      containerExecute "${containerName}" "${afterContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}" \
        "${afterContainerStartDockerParameters[@]}"
    fi
  else
    if [[ -n "${afterContainerStartDockerUser}" ]]; then
      containerExecuteUser "${containerName}" "${afterContainerStartDockerUser}" "${afterContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    else
      containerExecute "${containerName}" "${afterContainerStartDockerScript}" \
        --systemName "${systemName}" \
        --serverName "${serverName}" \
        --hostUserName "${USER}" \
        --hostUserId "${UID}"
    fi
  fi
fi
