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

if [[ -z "${useNamedVolumes}" ]]; then
  useNamedVolumes="false"
fi

if [[ -n "${beforeContainerCreateTargetScript}" ]]; then
  echo "Before container create target script: ${beforeContainerCreateTargetScript}"
  if [[ -n "${beforeContainerCreateTargetParameters}" ]]; then
    "${beforeContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerCreateTargetParameters[@]}"
  else
    "${beforeContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerCreateTargetDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container create target docker script: ${beforeContainerCreateTargetDockerScript}"
  if [[ -n "${beforeContainerCreateTargetDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerCreateTargetDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${beforeContainerCreateTargetDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerCreateTargetDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName,,}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag,,}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No target image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No target image tag for server: ${serverName}"
  exit 1
fi

if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 0 ]]; then
  >&2 echo "Required target image: ${imageName,,}:${imageTag,,} does not exist"
  exit 1
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
  echo "Image requires interactive run"
  if [[ -n "${imageInteractiveCommand}" ]]; then
    echo "Running image with command: ${imageInteractiveCommand}"
    containerRun "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "${imageInteractiveCommand}" "${optionalParameters[@]}"
  else
    containerRun "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "-" "${optionalParameters[@]}"
  fi
  exit 0
fi

if [[ $(containerExists "${containerName}") == 1 ]] && [[ "${force}" == 1 ]]; then
  containerRemove "${containerName}" "${useNamedVolumes}"

  mkdir -p "${anodosysUserVarPath}/commencement"
  rm -rf "${anodosysUserVarPath}/commencement/${containerName}"
  mkdir -p "${anodosysUserVarPath}/production"
  rm -rf "${anodosysUserVarPath}/production/${containerName}"
  mkdir -p "${anodosysUserVarPath}/finishing"
  rm -rf "${anodosysUserVarPath}/finishing/${containerName}"
fi

containerCreate "${imageName,,}:${imageTag,,}" "${containerName}" "${systemName}" "${serverName}" "${useNamedVolumes}" "${optionalParameters[@]}"

if [[ -n "${afterContainerCreateTargetScript}" ]]; then
  echo "After container create target script: ${afterContainerCreateTargetScript}"
  if [[ -n "${afterContainerCreateTargetParameters}" ]]; then
    "${afterContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerCreateTargetParameters[@]}"
  else
    "${afterContainerCreateTargetScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerCreateTargetDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container create target docker script: ${afterContainerCreateTargetDockerScript}"
  if [[ -n "${afterContainerCreateTargetDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerCreateTargetDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${afterContainerCreateTargetDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerCreateTargetDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi
