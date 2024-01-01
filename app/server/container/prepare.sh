#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

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

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

logName "${systemName}" "${serverName}"

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -n "${beforeContainerPrepareScript}" ]]; then
  echo "Before container prepare script: ${beforeContainerPrepareScript}"
  if [[ -n "${beforeContainerPrepareParameters}" ]]; then
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerPrepareParameters[@]}"
  else
    "${beforeContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerPaths}" ]]; then
  for containerPath in "${containerPaths[@]}"; do
    readarray -d : -t containerPathParts < <(printf '%s' "${containerPath}")
    containerPath="${containerPathParts[0]}"
    accessUser="${containerPathParts[1]}"
    mode="${containerPathParts[2]}"
    containerPath "${containerName}" "${containerPath}" "${accessUser}" "${mode}"
  done
fi

configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"
containerCopy "${containerName}" "${configurationFile}" "/container.sh"

if [[ -n "${containerPrepareFiles}" ]]; then
  for containerPrepareFile in "${containerPrepareFiles[@]}"; do
    containerCopy "${containerName}" "${containerPrepareFile}"
  done
fi

if [[ -n "${containerPrepareScript}" ]]; then
  echo "Container prepare script: ${containerPrepareScript}"
  if [[ -n "${containerPrepareParameters}" ]]; then
    "${containerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerPrepareParameters[@]}"
  else
    "${containerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
elif [[ -n "${containerPrepare}" ]]; then
  containerCommand "${containerName}" "${containerPrepare}"
else
  echo "Nothing to prepare"
fi

if [[ -n "${afterContainerPrepareScript}" ]]; then
  echo "After container prepare script: ${afterContainerPrepareScript}"
  if [[ -n "${afterContainerPrepareParameters}" ]]; then
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerPrepareParameters[@]}"
  else
    "${afterContainerPrepareScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi
