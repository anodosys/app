#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
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

if [[ -n "${beforeContainerRemoveScript}" ]]; then
  echo "Before container remove script: ${beforeContainerRemoveScript}"
  if [[ -n "${beforeContainerRemoveParameters}" ]]; then
    "${beforeContainerRemoveScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerRemoveParameters[@]}"
  else
    "${beforeContainerRemoveScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

containerName="${systemName}_${serverName}"

containerRemove "${containerName}"

if [[ -z "${containerVolumes}" ]]; then
  containerVolumes=()
fi

for containerVolume in "${containerVolumes[@]}"; do
  containerVolume=$(trim "${containerVolume}")
  readarray -d : -t containerVolumeParts < <(printf '%s' "${containerVolume}")
  sourcePath="${containerVolumeParts[0]}"
  containerVolumeRemove "${containerName}" "${sourcePath}"
done

if [[ -n "${afterContainerRemoveScript}" ]]; then
  echo "After container remove script: ${afterContainerRemoveScript}"
  if [[ -n "${afterContainerRemoveParameters}" ]]; then
    "${afterContainerRemoveScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerRemoveParameters[@]}"
  else
    "${afterContainerRemoveScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/commencement"
rm -rf "${anodosysUserVarPath}/commencement/${containerName}"
mkdir -p "${anodosysUserVarPath}/production"
rm -rf "${anodosysUserVarPath}/production/${containerName}"
mkdir -p "${anodosysUserVarPath}/finishing"
rm -rf "${anodosysUserVarPath}/finishing/${containerName}"
