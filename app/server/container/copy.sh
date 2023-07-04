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
  -f  local file path
  -r  remote file path (optional)

Example: ${scriptName} -s web -f "/path/to/local/file" -r "/path/to/remote/file"
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
localFileName=
remoteFileName=

while getopts hs:f:r:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    f) localFileName=$(trim "$OPTARG");;
    r) remoteFileName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

if [[ -z "${localFileName}" ]]; then
  >&2 echo "No local file name specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -n "${remoteFileName}" ]]; then
  containerCopy "${containerName}" "${localFileName}" "${remoteFileName}"
else
  containerCopy "${containerName}" "${localFileName}"
fi
