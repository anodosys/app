#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name
  -i  Image source (source or target)

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
imageSource=

while getopts hs:i:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    i) imageSource=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

logName "${systemName}" "${serverName}"

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerCreateScript}" ]]; then
  echo "Before container create script: ${beforeContainerCreateScript}"
  "${beforeContainerCreateScript}"
fi

if [[ "${imageSource}" == "target" ]]; then
  if [[ -n "${buildImageName}" ]]; then
    imageName="${buildImageName}"
  fi
  if [[ -n "${buildImageTag}" ]]; then
    imageTag="${buildImageTag}"
  fi
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No image tag for server: ${serverName}"
  exit 1
fi

containerName="${systemName}_${serverName}"

if [[ $(containerExists "${containerName}") == 0 ]] && [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
  >&2 echo "Required image: ${imageName}:${imageTag} does not exist"
  exit 1
fi

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  containerRun "${imageName}:${imageTag}" "${containerName}"
  exit 0
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

containerCreate "${imageName}:${imageTag}" "${containerName}" "${systemName}" "${optionalParameters[@]}"

if [[ -n "${afterContainerCreateScript}" ]]; then
  echo "After container create script: ${afterContainerCreateScript}"
  "${afterContainerCreateScript}"
fi
