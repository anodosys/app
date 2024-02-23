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

if [[ -n "${beforeContainerCreateSourceScript}" ]]; then
  echo "Before container create source script: ${beforeContainerCreateSourceScript}"
  if [[ -n "${beforeContainerCreateSourceParameters}" ]]; then
    "${beforeContainerCreateSourceScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerCreateSourceParameters[@]}"
  else
    "${beforeContainerCreateSourceScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerCreateSourceDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container create source docker script: ${beforeContainerCreateSourceDockerScript}"
  if [[ -n "${beforeContainerCreateSourceDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerCreateSourceDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${beforeContainerCreateSourceDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerCreateSourceDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No source image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No source image tag for server: ${serverName}"
  exit 1
fi

containerName="${systemName}_${serverName}"

if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 0 ]]; then
  >&2 echo "Required source image: ${imageName,,}:${imageTag,,} does not exist"
  exit 1
fi

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  exit 0
fi

if [[ -z "${useNamedVolumes}" ]]; then
  useNamedVolumes="false"
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

containerCreate "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "${optionalParameters[@]}"

if [[ -n "${afterContainerCreateSourceScript}" ]]; then
  echo "After container create source script: ${afterContainerCreateSourceScript}"
  if [[ -n "${afterContainerCreateSourceParameters}" ]]; then
    "${afterContainerCreateSourceScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerCreateSourceParameters[@]}"
  else
    "${afterContainerCreateSourceScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerCreateSourceDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container create source docker script: ${afterContainerCreateSourceDockerScript}"
  if [[ -n "${afterContainerCreateSourceDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerCreateSourceDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${afterContainerCreateSourceDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerCreateSourceDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi
