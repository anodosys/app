#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No anodosys user var configuration path defined!"
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

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -n "${containerDuplicates}" ]]; then
  for containerDuplicate in "${containerDuplicates[@]}"; do
    readarray -d : -t containerDuplicateParts < <(printf '%s' "${containerDuplicate}")
    localPath="${containerDuplicateParts[0]}"
    remotePath="${containerDuplicateParts[1]}"
    if test "${containerDuplicateParts[2]+isset}"; then
      remoteUserName="${containerDuplicateParts[2]}"
    else
      remoteUserName="-"
    fi
    if test "${containerDuplicateParts[3]+isset}"; then
      remoteGroupName="${containerDuplicateParts[3]}"
    else
      remoteGroupName="-"
    fi
    if test "${containerDuplicateParts[4]+isset}"; then
      remoteAccessRights="${containerDuplicateParts[4]}"
    else
      remoteAccessRights="-"
    fi
    containerCopy "${containerName}" "${localPath}" "${remotePath}" "${remoteUserName}" "${remoteGroupName}" "${remoteAccessRights}"
  done
fi
