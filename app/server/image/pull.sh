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

if [[ -n "${beforeImagePullScript}" ]]; then
  echo "Before image pull script: ${beforeImagePullScript}"
  "${beforeImagePullScript}"
fi

containerName="${systemName}_${serverName}"

if [[ $(containerExists "${containerName}") == 1 ]]; then
  echo "No need to pull image"
  exit 0
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No image tag for server: ${serverName}"
  exit 1
fi

if [[ "${imageSource}" == "target" ]]; then
  if [[ -n "${buildImageName}" ]]; then
    imageName="${buildImageName}"
  fi
  if [[ -n "${buildImageTag}" ]]; then
    imageTag="${buildImageTag}"
  fi
fi

if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
  if [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
    imagePull "${imageName}" "${imageTag}"
  else
    echo "Image does not exist: ${imageName}:${imageTag}"
  fi
else
  echo "No need to pull image: ${imageName}:${imageTag}"
fi

if [[ -n "${afterImagePullScript}" ]]; then
  echo "After image pull script: ${afterImagePullScript}"
  "${afterImagePullScript}"
fi
