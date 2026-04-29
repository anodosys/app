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
  -q  Flag if the command is hidden

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
quiet=0

while getopts hs:f:r:q? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    f) localFileName=$(trim "$OPTARG");;
    r) remoteFileName=$(trim "$OPTARG");;
    q) quiet=1;;
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

if [[ "${quiet}" == 0 ]]; then
  if [[ -n "${remoteFileName}" ]]; then
    containerCopy "${containerName}" "${localFileName}" "${remoteFileName}"
  else
    containerCopy "${containerName}" "${localFileName}"
  fi
else
  if [[ -n "${remoteFileName}" ]]; then
    containerCopyQuiet "${containerName}" "${localFileName}" "${remoteFileName}"
  else
    containerCopyQuiet "${containerName}" "${localFileName}"
  fi
fi
