#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

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

containerName="${systemName}_${serverName}"

if [[ -n "${beforeContainerNotRunningScript}" ]]; then
  echo "Before container not running script: ${beforeContainerNotRunningScript}"
  if [[ -n "${beforeContainerNotRunningParameters}" ]]; then
    "${beforeContainerNotRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerNotRunningParameters[@]}"
  else
    "${beforeContainerNotRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerNotRunningDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container not running docker script: ${beforeContainerNotRunningDockerScript}"
  if [[ -n "${beforeContainerNotRunningDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerNotRunningDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerNotRunningDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerNotRunningDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ $(containerRunning "${containerName}") == 1 ]]; then
  >&2 echo "Container already running: ${containerName}"
  if [[ "${force}" == 0 ]]; then
    exit 1
  fi
else
  echo "Container not running: ${containerName}"
fi

if [[ -n "${afterContainerNotRunningScript}" ]]; then
  echo "After container not running script: ${afterContainerNotRunningScript}"
  if [[ -n "${afterContainerNotRunningParameters}" ]]; then
    "${afterContainerNotRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerNotRunningParameters[@]}"
  else
    "${afterContainerNotRunningScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerNotRunningDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container not running docker script: ${afterContainerNotRunningDockerScript}"
  if [[ -n "${afterContainerNotRunningDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerNotRunningDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerNotRunningDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerNotRunningDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi
