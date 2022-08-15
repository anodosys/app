#!/bin/bash -e

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

if [[ -n "${beforeImagePullTargetScript}" ]]; then
  echo "Before image pull target script: ${beforeImagePullTargetScript}"
  "${beforeImagePullTargetScript}"
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No target image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No target image tag for server: ${serverName}"
  exit 1
fi

if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
  if [[ -n "${repositoryUserName}" ]] && [[ -n "${repositoryPassword}" ]] && [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}") == 1 ]]; then
    imagePull "${imageName}" "${imageTag}"
  elif [[ -z "${repositoryUserName}" ]]; then
    >&2 echo "No repository user name for server: ${serverName}"
    exit 1
  elif [[ -z "${repositoryPassword}" ]]; then
    >&2 echo "No repository password for server: ${serverName}"
    exit 1
  else
    >&2 echo "Target image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
else
  echo "No need to pull target image: ${imageName}:${imageTag}"
fi

if [[ -n "${afterImagePullTargetScript}" ]]; then
  echo "After image pull target script: ${afterImagePullTargetScript}"
  "${afterImagePullTargetScript}"
fi
