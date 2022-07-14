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

if [[ -n "${beforeImageCreateScript}" ]]; then
  echo "Before image create script: ${beforeImageCreateScript}"
  "${beforeImageCreateScript}"
fi

if [[ -z "${buildImageName}" ]] || [[ -z "${buildImageTag}" ]]; then
  echo "No creating of image required"
  exit 0
fi

containerName="${systemName}_${serverName}"

if [[ -n "${buildImageEntryPoint}" ]]; then
  imageCreate "${buildImageName}" "${buildImageTag}" "${containerName}" "${buildImageEntryPoint}"
else
  imageCreate "${buildImageName}" "${buildImageTag}" "${containerName}"
fi

if [[ -n "${afterImageCreateScript}" ]]; then
  echo "After image create script: ${afterImageCreateScript}"
  "${afterImageCreateScript}"
fi
