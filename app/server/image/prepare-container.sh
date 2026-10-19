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

if [[ -n "${beforeImagePrepareContainerScript}" ]]; then
  echo "Before container prepare for image create script: ${beforeImagePrepareContainerScript}"
  "${beforeImagePrepareContainerScript}" \
    --systemName "${systemName}" \
    --serverName "${serverName}"
fi

if [[ -n "${imagePrepareContainerScript}" ]]; then
  echo "Container prepare for image create script: ${imagePrepareContainerScript}"
  "${imagePrepareContainerScript}" \
    --systemName "${systemName}" \
    --serverName "${serverName}"
fi

if [[ -n "${afterImagePrepareContainerScript}" ]]; then
  echo "After container prepare for image create script: ${afterImagePrepareContainerScript}"
  "${afterImagePrepareContainerScript}" \
    --systemName "${systemName}" \
    --serverName "${serverName}"
fi
