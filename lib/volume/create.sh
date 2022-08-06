#!/bin/bash -e

volumeCreate()
{
  local volumeName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-local}"
  local mode="${5:-r}"
  local userId
  local user
  local groupId
  local group
  local rights
  local empty
  local result

  userId=$(stat -c '%u' "${sourcePath}")
  user=$(stat -c '%U' "${sourcePath}")
  groupId=$(stat -c '%g' "${sourcePath}")
  group=$(stat -c '%G' "${sourcePath}")
  rights=$(stat -c '%a' "${sourcePath}")
  empty=$(find "${sourcePath}" -maxdepth 0 -empty | read -r && echo "true" || echo "false")

  if [[ $(volumeExists "${volumeName}") == 0 ]]; then
    echo "Creating volume: ${volumeName} with source path: ${sourcePath} and target path: ${targetPath} accessible by user: ${targetUser} and mode: ${mode}"
    result=$(docker volume create \
      --driver local \
      --opt type=none \
      --opt device="${sourcePath}" \
      --opt o=bind \
      --name "${volumeName}" \
      --label "sourcePath=${sourcePath}" \
      --label "targetPath=${targetPath}" \
      --label "targetUser=${targetUser}" \
      --label "mode=${mode}" \
      --label "userId=${userId}" \
      --label "user=${user}" \
      --label "groupId=${groupId}" \
      --label "group=${group}" \
      --label "rights=${rights}" \
      --label "empty=${empty}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully created volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create volume: ${volumeName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx volumeCreate
