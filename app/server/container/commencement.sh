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

commenced=$(containerCommandQuiet "${containerName}" "test -f /.commenced.flag && echo -n \"true\" || echo -n \"false\"")

if [[ "${commenced}" == "true" ]]; then
  echo "Nothing to commence"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerCommencementScript}" ]]; then
  echo "Before container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${beforeContainerCommencementParameters}" ]]; then
    "${beforeContainerCommencementScript}" "${beforeContainerCommencementParameters[@]}"
  else
    "${beforeContainerCommencementScript}"
  fi
fi

if [[ -n "${containerCommencementScript}" ]]; then
  echo "Container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${containerCommencementParameters}" ]]; then
    "${containerCommencementScript}" --containerName "${containerName}" "${containerCommencementParameters[@]}"
  else
    "${containerCommencementScript}" --containerName "${containerName}"
  fi
elif [[ -n "${containerCommencement}" ]]; then
  containerCommand "${containerName}" "${containerCommencement}"
else
  echo "Nothing to commence"
fi

if [[ -n "${afterContainerCommencementScript}" ]]; then
  echo "After container commencement script: ${afterContainerCommencementScript}"
  if [[ -n "${afterContainerCommencementParameters}" ]]; then
    "${afterContainerCommencementScript}" "${afterContainerCommencementParameters[@]}"
  else
    "${afterContainerCommencementScript}"
  fi
fi

containerCommandQuiet "${containerName}" "touch /.commenced.flag"
