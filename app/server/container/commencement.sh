#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

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

if [[ -f "${anodosysUserVarPath}/commencement/${containerName}" ]]; then
  echo "Commencement already processed"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerCommencementScript}" ]]; then
  echo "Before container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${beforeContainerCommencementParameters}" ]]; then
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerCommencementParameters[@]}"
  else
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${beforeContainerCommencementDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container commencement docker script: ${beforeContainerCommencementDockerScript}"
  if [[ -n "${beforeContainerCommencementDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${beforeContainerCommencementDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

if [[ -n "${containerCommencementScript}" ]]; then
  echo "Container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${containerCommencementParameters}" ]]; then
    "${containerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerCommencementParameters[@]}"
  else
    "${containerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerCommencementDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Container commencement docker script: ${containerCommencementDockerScript}"
  if [[ -n "${containerCommencementDockerParameters}" ]]; then
    containerExecute "${containerName}" "${containerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${containerCommencementDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${containerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

if [[ -n "${containerCommencement}" ]]; then
  containerCommand "${containerName}" "${containerCommencement}"
fi

if [[ -n "${afterContainerCommencementScript}" ]]; then
  echo "After container commencement script: ${afterContainerCommencementScript}"
  if [[ -n "${afterContainerCommencementParameters}" ]]; then
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerCommencementParameters[@]}"
  else
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${afterContainerCommencementDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container commencement docker script: ${afterContainerCommencementDockerScript}"
  if [[ -n "${afterContainerCommencementDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}" \
      "${afterContainerCommencementDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerCommencementDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --hostUserName "${USER}" \
      --hostUserId "${UID}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/commencement"
touch "${anodosysUserVarPath}/commencement/${containerName}"
