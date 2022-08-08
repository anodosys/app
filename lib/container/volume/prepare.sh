#!/bin/bash -e

containerVolumePrepare()
{
  local containerName="${1}"
  local volumeNames
  local volumeName
  local groupUserList
  local sourcePath
  local targetPath
  local targetUser
  local groupId
  local groupName
  local userNames
  local userNameList
  local userId
  local result

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeNames=( $(containerVolumeList "${containerName}" ) )
    IFS="${oldIFS}"

    declare -A groupUserList
    for volumeName in "${volumeNames[@]}"; do
      volumeName=$(trim "${volumeName}")

      if [[ $(volumeExists "${volumeName}") == 1 ]]; then
        echo "Preparing volume: ${volumeName}"

        sourcePath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".sourcePath // empty")
        targetPath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetPath // empty")
        empty=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".empty // empty")

        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${empty}" == "true" ]]; then
          userId=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".userId // empty")
          groupId=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".groupId // empty")
          rights=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".rights // empty")
          if [[ -n "${userId}" ]] && [[ -n "${groupId}" ]]; then
            containerCommand "${containerName}" "chown ${userId}:${groupId} ${targetPath}"
          fi
          if [[ -n "${rights}" ]]; then
            containerCommand "${containerName}" "chmod ${rights} ${targetPath}"
          fi
        fi

        targetUser=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetUser // empty")
        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ -n "${targetUser}" ]]; then
          groupId=$(stat -c '%g' "${sourcePath}")
          if test "${groupUserList[${groupId}]+isset}"; then
            groupUserList[${groupId}]+=",${targetUser}"
          else
            groupUserList[${groupId}]="${targetUser}"
          fi
        else
          echo "No need to prepare volume: ${volumeName}"
        fi
      else
        >&2 echo "Volume does not exist: ${volumeName}"
        exit 1
      fi
    done

    for groupId in "${!groupUserList[@]}"; do
      groupName=$(containerCommandQuiet "${containerName}" "getent group ${groupId} | tr ':' ' ' | awk '{print \$1}'")
      groupName=$(prepareValue "${groupName}")

      if [[ -z "${groupName}" ]]; then
        groupName="docker_volume_${groupId}"
        echo "Creating new group: ${groupName}"
        containerCommand "${containerName}" "groupadd -g ${groupId} ${groupName}"
      else
        echo "No need to create group: ${groupName}"
      fi

      userNames="${groupUserList[${groupId}]}"
      userNameList=( $(echo "${userNames}" | sed -e 's/,/\n/g' | sort -u) )

      for targetUser in "${userNameList[@]}"; do
        if [[ "${targetUser}" == "local" ]]; then
          userId="${UID}"
          targetUser=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | tr ':' ' ' | awk '{print \$1}'")
          targetUser=$(prepareValue "${targetUser}")

          if [[ -z "${targetUser}" ]]; then
            targetUser="docker_volume_${userId}"
            echo "Creating new user: ${targetUser}"
            containerCommand "${containerName}" "useradd -m -u ${userId} -g ${groupId} ${targetUser}"
          fi
        fi

        result=$(containerCommandQuiet "${containerName}" "id -nG ${targetUser} | grep -w ${groupName} | wc -l")
        result=$(prepareValue "${result}")

        if [[ "${result}" == 0 ]]; then
          echo "Adding user: ${targetUser} to group: ${groupName}"
          containerCommand "${containerName}" "usermod -a -G ${groupName} ${targetUser}"
        else
          echo "No need to add user: ${targetUser} to group: ${groupName}"
        fi
      done
    done
  else
    echo "Not possible to prepare volumes of container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumePrepare
