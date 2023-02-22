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

containerName="${systemName}_${serverName}"

if [[ -n "${beforeContainerDismantleScript}" ]]; then
  echo "Before container dismantle script: ${beforeContainerDismantleScript}"
  if [[ -n "${beforeContainerDismantleParameters}" ]]; then
    "${beforeContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerDismantleParameters[@]}"
  else
    "${beforeContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerDismantleScript}" ]]; then
  echo "Container dismantle script: ${containerDismantleScript}"
  if [[ -n "${containerDismantleParameters}" ]]; then
    "${containerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerDismantleParameters[@]}"
  else
    "${containerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
elif [[ -n "${containerDismantle}" ]]; then
  containerCommand "${containerName}" "${containerDismantle}"
else
  echo "Nothing to dismantle"
fi

if [[ -n "${afterContainerDismantleScript}" ]]; then
  echo "After container dismantle script: ${afterContainerDismantleScript}"
  if [[ -n "${afterContainerDismantleParameters}" ]]; then
    "${afterContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerDismantleParameters[@]}"
  else
    "${afterContainerDismantleScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi
