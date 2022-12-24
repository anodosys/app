#!/bin/bash -e

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

if [[ -n "${beforeImageRemoveTargetLocalScript}" ]]; then
  echo "Before image remove target local script: ${beforeImageRemoveTargetLocalScript}"
  "${beforeImageRemoveTargetLocalScript}"
fi

if [[ -z "${buildImageName}" ]] && [[ -z "${buildImageTag}" ]]; then
  echo "No removing of local target image required"
  exit 0
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

imageRemove "${imageName}" "${imageTag}" "warn"

if [[ -n "${afterImageRemoveTargetLocalScript}" ]]; then
  echo "After image remove target local script: ${afterImageRemoveTargetLocalScript}"
  "${afterImageRemoveTargetLocalScript}"
fi
