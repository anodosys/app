#!/bin/bash -e

if [[ -z "${anodosysUserVarVolumePath}" ]]; then
  >&2 echo "No anodosys user var volume path defined"
  exit 1
fi

volumeMetadataFilePath()
{
  local sourcePath="${1}"
  local sourcePathHash
  local volumeMetadataFilePath

  sourcePathHash=$(echo "${sourcePath}" | md5sum | awk '{print $1}')
  volumeMetadataFilePath="${anodosysUserVarVolumePath}/${sourcePathHash}.json"

  echo -n "${volumeMetadataFilePath}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataFilePath

volumeMetadataCreate()
{
  local sourcePath="${1}"
  local targetPath="${2}"
  local targetUser="${3:-local}"
  local mode="${4:-r}"
  local userId="${5}"
  local user="${6}"
  local groupId="${7}"
  local group="${8}"
  local rights="${9}"
  local empty="${10}"
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

  volumeMetadataFilePath=$(volumeMetadataFilePath "${sourcePath}")

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
  local sourcePath="${1}"
  local key="${2}"
  local volumeMetadataFilePath

  volumeMetadataFilePath=$(volumeMetadataFilePath "${sourcePath}")

  jq -r ".${key} // empty" "${volumeMetadataFilePath}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataGet

volumeMetadataRemove()
{
  local sourcePath="${1}"
  local volumeMetadataFilePath

  volumeMetadataFilePath=$(volumeMetadataFilePath "${sourcePath}")

  rm -rf "${volumeMetadataFilePath}"
}

# shellcheck disable=SC2034
typeset -fx volumeMetadataRemove
