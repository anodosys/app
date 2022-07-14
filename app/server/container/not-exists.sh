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

if [[ -n "${beforeContainerNotExistsScript}" ]]; then
  echo "Before container not exists script: ${beforeContainerNotExistsScript}"
  "${beforeContainerNotExistsScript}"
fi

containerName="${systemName}_${serverName}"

if [[ $(containerExists "${containerName}") == 1 ]]; then
  >&2 echo "Container already exists: ${containerName}"
  exit 1
else
  echo "Container does not exist: ${containerName}"
fi

if [[ -n "${afterContainerNotExistsScript}" ]]; then
  echo "After container not exists script: ${afterContainerNotExistsScript}"
  "${afterContainerNotExistsScript}"
fi
