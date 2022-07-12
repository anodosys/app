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

if [[ -n "${beforeContainerStartScript}" ]]; then
  echo "Before container start script: ${beforeContainerStartScript}"
  "${beforeContainerStartScript}"
fi

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  echo "Image requires interactive run"
  exit 0
fi

containerName="${systemName}_${serverName}"

containerStart "${containerName}"

if [[ -n "${afterContainerStartScript}" ]]; then
  echo "After container start script: ${afterContainerStartScript}"
  "${afterContainerStartScript}"
fi
