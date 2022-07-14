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

if [[ -n "${beforeImageRemoveRemoteScript}" ]]; then
  echo "Before image remove script: ${beforeImageRemoveRemoteScript}"
  "${beforeImageRemoveRemoteScript}"
fi

if [[ -z "${buildImageName}" ]] || [[ -z "${buildImageTag}" ]]; then
  echo "No removing of remote image required"
  exit 0
fi

if [[ -n "${repositoryUserName}" ]] && [[ -n "${repositoryPassword}" ]]; then
  imageRemoveRemote "${buildImageName}" "${buildImageTag}" "${repositoryUserName}" "${repositoryPassword}"
fi

if [[ -n "${afterImageRemoveRemoteScript}" ]]; then
  echo "After image remove script: ${afterImageRemoveRemoteScript}"
  "${afterImageRemoveRemoteScript}"
fi
