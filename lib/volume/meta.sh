#!/bin/bash -e

if [[ -z "${anodosysUserVarVolumePath}" ]]; then
  >&2 echo "No anodosys user var volume path defined"
  exit 1
fi

volumeMetadataFilePath()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local checkFileExists="${3:-yes}"
  local sourcePathHash
  local volumeMetadataFilePath

  sourcePathHash=$(echo "${containerName}:${sourcePath}" | md5sum | awk '{print $1}')
  volumeMetadataFilePath="${anodosysUserVarVolumePath}/${sourcePathHash}.json"

  if [[ -f "${volumeMetadataFilePath}" ]] || [[ "${checkFileExists}" == "no" ]]; then
    echo -n "${volumeMetadataFilePath}"
  else
    sourcePathHash=$(echo "${sourcePath}" | md5sum | awk '{print $1}')
    volumeMetadataFilePath="${anodosysUserVarVolumePath}/${sourcePathHash}.json"
    echo -n "${volumeMetadataFilePath}"
  fi
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataFilePath

volumeMetadataCreate()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-local}"
  local mode="${5:-r}"
  local userId="${6}"
  local user="${7}"
  local groupId="${8}"
  local group="${9}"
  local rights="${10}"
  local empty="${11}"
  local volumeMetadataFilePath

  if [[ -z "${userId}" ]] || [[ "${userId}" == "-" ]]; then
    userId=$(stat -c '%u' "${sourcePath}")
  fi
  if [[ -z "${user}" ]] || [[ "${user}" == "-" ]]; then
    user=$(stat -c '%U' "${sourcePath}")
  fi
  if [[ -z "${groupId}" ]] || [[ "${groupId}" == "-" ]]; then
    groupId=$(stat -c '%g' "${sourcePath}")
  fi
  if [[ -z "${group}" ]] || [[ "${group}" == "-" ]]; then
    group=$(stat -c '%G' "${sourcePath}")
  fi
  if [[ -z "${rights}" ]] || [[ "${rights}" == "-" ]]; then
    rights=$(stat -c '%a' "${sourcePath}")
  fi
  if [[ -z "${empty}" ]] || [[ "${empty}" == "-" ]]; then
    empty=$(find "${sourcePath}" -maxdepth 0 -empty | read -r && echo "true" || echo "false")
  fi

  volumeMetadataFilePath=$(volumeMetadataFilePath "${containerName}" "${sourcePath}" "no")

  updateJson "${volumeMetadataFilePath}" "sourcePath" "${sourcePath}"
  updateJson "${volumeMetadataFilePath}" "targetPath" "${targetPath}"
  updateJson "${volumeMetadataFilePath}" "targetUser" "${targetUser}"
  updateJson "${volumeMetadataFilePath}" "mode" "${mode}"
  updateJson "${volumeMetadataFilePath}" "userId" "${userId}"
  updateJson "${volumeMetadataFilePath}" "user" "${user}"
  updateJson "${volumeMetadataFilePath}" "groupId" "${groupId}"
  updateJson "${volumeMetadataFilePath}" "group" "${group}"
  updateJson "${volumeMetadataFilePath}" "rights" "${rights}"
  updateJson "${volumeMetadataFilePath}" "empty" "${empty}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataCreate

volumeMetadataGet()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local key="${3}"
  local volumeMetadataFilePath

  volumeMetadataFilePath=$(volumeMetadataFilePath "${containerName}" "${sourcePath}")

  jq -r ".${key} // empty" "${volumeMetadataFilePath}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataGet

volumeMetadataRemove()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local volumeMetadataFilePath

  volumeMetadataFilePath=$(volumeMetadataFilePath "${containerName}" "${sourcePath}")

  rm -rf "${volumeMetadataFilePath}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataRemove
