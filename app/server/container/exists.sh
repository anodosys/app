#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${force}" ]]; then
  >&2 echo "No force status specified!"
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

if [[ -n "${beforeContainerExistsScript}" ]]; then
  echo "Before container exists script: ${beforeContainerExistsScript}"
  if [[ -n "${beforeContainerExistsParameters}" ]]; then
    "${beforeContainerExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerExistsParameters[@]}"
  else
    "${beforeContainerExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

containerName="${systemName}_${serverName}"

if [[ $(containerExists "${containerName}") == 0 ]]; then
  >&2 echo "Container does not exist: ${containerName}"
  if [[ "${force}" == 0 ]]; then
    exit 1
  fi
else
  echo "Container exists: ${containerName}"
fi

if [[ -n "${afterContainerExistsScript}" ]]; then
  echo "After container exists script: ${afterContainerExistsScript}"
  if [[ -n "${afterContainerExistsParameters}" ]]; then
    "${afterContainerExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerExistsParameters[@]}"
  else
    "${afterContainerExistsScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi
