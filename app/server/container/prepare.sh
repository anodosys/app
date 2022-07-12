#!/bin/bash -e

scriptName="${0##*/}"

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No anodosys user var configuration path defined!"
  exit 1
fi

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

if [[ -n "${beforeContainerPrepareScript}" ]]; then
  echo "Before container prepare script: ${beforeContainerPrepareScript}"
  "${beforeContainerPrepareScript}"
fi

containerName="${systemName}_${serverName}"

configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"
containerCopy "${containerName}" "${configurationFile}" "/container.sh"

if [[ -n "${containerPrepareFiles}" ]]; then
  for containerPrepareFile in "${containerPrepareFiles[@]}"; do
    containerCopy "${containerName}" "${containerPrepareFile}"
  done
fi

if [[ -n "${containerPrepareScript}" ]]; then
  if [[ -n "${containerPrepareParameters}" ]]; then
    containerExecute "${containerName}" "${containerPrepareScript}" "${containerPrepareParameters[@]}"
  else
    containerExecute "${containerName}" "${containerPrepareScript}"
  fi
elif [[ -n "${containerPrepare}" ]]; then
  containerCommand "${containerName}" "${containerPrepare}"
else
  echo "Nothing to prepare"
fi

if [[ -n "${afterContainerPrepareScript}" ]]; then
  echo "After container prepare script: ${afterContainerPrepareScript}"
  "${afterContainerPrepareScript}"
fi
