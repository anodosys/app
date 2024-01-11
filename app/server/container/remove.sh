#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

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

containerName="${systemName}_${serverName}"

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

if [[ -n "${beforeContainerRemoveDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "Before container remove docker script: ${beforeContainerRemoveDockerScript}"
  if [[ -n "${beforeContainerRemoveDockerParameters}" ]]; then
    containerExecute "${containerName}" "${beforeContainerRemoveDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerRemoveDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${beforeContainerRemoveDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -z "${useNamedVolumes}" ]]; then
  useNamedVolumes="false"
fi

containerRemove "${containerName}" "${useNamedVolumes}"

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

if [[ -n "${afterContainerRemoveDockerScript}" ]]; then
  containerCopy "${containerName}" "${anodosysAppPath}/prepare-parameters.sh"

  echo "After container remove docker script: ${afterContainerRemoveDockerScript}"
  if [[ -n "${afterContainerRemoveDockerParameters}" ]]; then
    containerExecute "${containerName}" "${afterContainerRemoveDockerScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerRemoveDockerParameters[@]}"
  else
    containerExecute "${containerName}" "${afterContainerRemoveDockerScript}" \
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
