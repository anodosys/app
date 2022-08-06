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

if [[ -n "${beforeImagePushScript}" ]]; then
  echo "Before image push script: ${beforeImagePushScript}"
  "${beforeImagePushScript}"
fi

if [[ -z "${buildImageName}" ]] && [[ -z "${buildImageTag}" ]]; then
  echo "No pushing of image required"
  exit 0
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

if [[ -n "${buildImageMode}" ]] && [[ "${buildImageMode}" == "remote" ]]; then
  imagePush "${imageName}" "${imageTag}"
else
  echo "No pushing of image required"
fi

if [[ -n "${afterImagePushScript}" ]]; then
  echo "After image push script: ${afterImagePushScript}"
  "${afterImagePushScript}"
fi
