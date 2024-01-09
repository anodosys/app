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

if [[ -n "${containerPaths}" ]]; then
  for containerPath in "${containerPaths[@]}"; do
    readarray -d : -t containerPathParts < <(printf '%s' "${containerPath}")
    containerPath="${containerPathParts[0]}"
    accessUser="${containerPathParts[1]}"
    if test "${containerPathParts[2]+isset}"; then
      mode="${containerPathParts[2]}"
    else
      mode="-"
    fi
    if test "${containerPathParts[3]+isset}"; then
      accessRights="${containerPathParts[3]}"
    else
      accessRights="-"
    fi
    containerPath "${containerName}" "${containerPath}" "${accessUser}" "${mode}" "${accessRights}"
  done
fi

if [[ -n "${containerCopies}" ]]; then
  for containerCopy in "${containerCopies[@]}"; do
    readarray -d : -t containerCopyParts < <(printf '%s' "${containerCopy}")
    localPath="${containerCopyParts[0]}"
    remotePath="${containerCopyParts[1]}"
    if test "${containerCopyParts[2]+isset}"; then
      remoteUserName="${containerCopyParts[2]}"
    else
      remoteUserName="-"
    fi
    if test "${containerCopyParts[3]+isset}"; then
      remoteGroupName="${containerCopyParts[3]}"
    else
      remoteGroupName="-"
    fi
    if test "${containerCopyParts[4]+isset}"; then
      remoteAccessRights="${containerCopyParts[4]}"
    else
      remoteAccessRights="-"
    fi
    containerCopy "${containerName}" "${localPath}" "${remotePath}" "${remoteUserName}" "${remoteGroupName}" "${remoteAccessRights}"
  done
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
elif [[ -n "${containerCommencement}" ]]; then
  containerCommand "${containerName}" "${containerCommencement}"
else
  echo "Nothing to commence"
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

mkdir -p "${anodosysUserVarPath}/commencement"
touch "${anodosysUserVarPath}/commencement/${containerName}"
