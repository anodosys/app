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

if [[ -n "${beforeImageRemoveSourceLocalScript}" ]]; then
  echo "Before image remove source local script: ${beforeImageRemoveSourceLocalScript}"
  "${beforeImageRemoveSourceLocalScript}"
fi

if [[ -z "${imageName}" ]] || [[ -z "${imageTag}" ]]; then
  echo "No removing of local source image required"
  exit 0
fi

if [[ $(imageUsed "${imageName}" "${imageTag}") == 1 ]]; then
  echo "Cannot not remove image: ${imageName}:${imageTag} because it is in use"
  exit 0
fi

imageRemove "${imageName}" "${imageTag}"

if [[ -n "${afterImageRemoveSourceLocalScript}" ]]; then
  echo "After image remove soource local script: ${afterImageRemoveSourceLocalScript}"
  "${afterImageRemoveSourceLocalScript}"
fi
