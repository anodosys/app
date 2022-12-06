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

containerName="${systemName}_${serverName}"

finished=$(containerCommandQuiet "${containerName}" "test -f /.finished.flag && echo -n \"true\" || echo -n \"false\"")

if [[ "${finished}" == "true" ]]; then
  echo "Nothing to finish"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerFinishingScript}" ]]; then
  echo "Before container finishing script: ${beforeContainerFinishingScript}"
  if [[ -n "${beforeContainerFinishingParameters}" ]]; then
    "${beforeContainerFinishingScript}" "${beforeContainerFinishingParameters[@]}"
  else
    "${beforeContainerFinishingScript}"
  fi
fi

if [[ -n "${containerFinishingScript}" ]]; then
  if [[ -n "${containerFinishingParameters}" ]]; then
    "${containerFinishingScript}" --containerName "${containerName}" "${containerFinishingParameters[@]}"
  else
    "${containerFinishingScript}" --containerName "${containerName}"
  fi
elif [[ -n "${containerFinishing}" ]]; then
  containerCommand "${containerName}" "${containerFinishing}"
else
  echo "Nothing to finish"
fi

if [[ -n "${afterContainerFinishingScript}" ]]; then
  echo "After container finishing script: ${afterContainerFinishingScript}"
  if [[ -n "${afterContainerFinishingParameters}" ]]; then
    "${afterContainerFinishingScript}" "${afterContainerFinishingParameters[@]}"
  else
    "${afterContainerFinishingScript}"
  fi
fi

containerCommandQuiet "${containerName}" "touch /.finished.flag"
