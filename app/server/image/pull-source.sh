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

if [[ -n "${beforeImagePullSourceScript}" ]]; then
  echo "Before image pull source script: ${beforeImagePullSourceScript}"
  "${beforeImagePullSourceScript}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No source image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No source image tag for server: ${serverName}"
  exit 1
fi

if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
  if [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
    imagePull "${imageName}" "${imageTag}"
  else
    >&2 echo "Source image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
else
  echo "No need to pull source image: ${imageName}:${imageTag}"
fi

if [[ -n "${afterImagePullSourceScript}" ]]; then
  echo "After image pull source script: ${afterImagePullSourceScript}"
  "${afterImagePullSourceScript}"
fi
