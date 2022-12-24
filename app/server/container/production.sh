#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

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

if [[ -f "${anodosysUserVarPath}/production/${containerName}" ]]; then
  echo "Production already processed"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerProductionScript}" ]]; then
  echo "Before container production script: ${beforeContainerProductionScript}"
  if [[ -n "${beforeContainerProductionParameters}" ]]; then
    "${beforeContainerProductionScript}" "${beforeContainerProductionParameters[@]}"
  else
    "${beforeContainerProductionScript}"
  fi
fi

if [[ -n "${containerProductionScript}" ]]; then
  if [[ -n "${containerProductionParameters}" ]]; then
    "${containerProductionScript}" --containerName "${containerName}" "${containerProductionParameters[@]}"
  else
    "${containerProductionScript}" --containerName "${containerName}"
  fi
elif [[ -n "${containerProduction}" ]]; then
  containerCommand "${containerName}" "${containerProduction}"
else
  echo "Nothing to produce"
fi

if [[ -n "${afterContainerProductionScript}" ]]; then
  echo "After container production script: ${afterContainerProductionScript}"
  if [[ -n "${afterContainerProductionParameters}" ]]; then
    "${afterContainerProductionScript}" "${afterContainerProductionParameters[@]}"
  else
    "${afterContainerProductionScript}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/production"
touch "${anodosysUserVarPath}/production/${containerName}"
