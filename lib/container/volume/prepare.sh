#!/bin/bash -e

containerVolumePrepare()
{
  local containerName="${1}"
  local useNamedVolumes="${2}"
  local volumeSourcePaths
  local volumeSourcePath
  local volumeMetadataFilePath
  local groupUserList
  local targetPathUserList
  local sourcePath
  local targetPath
  local empty
  local userId
  local groupId
  local rights
  local mode
  local targetUser
  local groupName
  local userName
  local userNames
  local userNameList
  local result
  local targetPathGroupId
  local targetPathGroupName
  local targetPathUserId
  local targetPathUserName

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeSourcePaths=( $(containerVolumeSourcePathList "${containerName}" ) )
    IFS="${oldIFS}"

    declare -A groupUserList
    targetPathUserList=()

    for volumeSourcePath in "${volumeSourcePaths[@]}"; do
      volumeSourcePath=$(trim "${volumeSourcePath}")
      volumeMetadataFilePath=$(volumeMetadataFilePath "${containerName}" "${volumeSourcePath}")

      if [[ -f "${volumeMetadataFilePath}" ]]; then
        echo "Preparing source path: ${volumeSourcePath}"

        sourcePath=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "sourcePath")
        targetPath=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "targetPath")
        empty=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "empty")

        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${empty}" == "true" ]]; then
          userId=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "userId")
          groupId=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "groupId")

          if [[ "${useNamedVolumes}" == "true" ]]; then
            rights=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "rights")

            if [[ -n "${userId}" ]] && [[ -n "${groupId}" ]]; then
              containerCommand "${containerName}" "chown ${userId}:${groupId} ${targetPath}"
              if [[ $(containerCommandQuiet "${containerName}" "test -L ${targetPath} && stat -c \"%u\" \$(readlink ${targetPath}) || stat -c \"%u\" ${targetPath}") == "${userId}" ]] && [[ $(containerCommandQuiet "${containerName}" "test -L ${targetPath} && stat -c \"%g\" \$(readlink ${targetPath}) || stat -c \"%g\" ${targetPath}") == "${groupId}" ]]; then
                echo "Successfully changed owner of target path: ${targetPath} to: ${userId}:${groupId}" | sed $'s,.*,\e[1;36m&\e[m,'
              else
                >&2 echo "Could not change owner of target path: ${targetPath} to: ${userId}:${groupId}"
                exit 1
              fi
            fi

            if [[ -n "${rights}" ]]; then
              containerCommand "${containerName}" "chmod ${rights} ${targetPath}"
              if [[ $(containerCommandQuiet "${containerName}" "test -L ${targetPath} && stat -c \"%a\" \$(readlink ${targetPath}) || stat -c \"%a\" ${targetPath}") == "${rights}" ]]; then
                echo "Successfully changed rights of target path: ${targetPath} to: ${rights}" | sed $'s,.*,\e[1;36m&\e[m,'
              else
                >&2 echo "Could not change rights of target path: ${targetPath} to: ${rights}"
                exit 1
              fi
            fi
          fi
        fi

        targetUser=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "targetUser")
        mode=$(volumeMetadataGet "${containerName}" "${volumeSourcePath}" "mode")

        if [[ "${mode}" == "r" ]] || [[ "${mode}" == "w" ]] || [[ "${mode}" == "l" ]]; then
          if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ -n "${targetUser}" ]]; then
            groupId=$(stat -c '%g' "${sourcePath}")
            if test "${groupUserList[${groupId}]+isset}"; then
              groupUserList[${groupId}]+=",${targetUser}"
            else
              groupUserList[${groupId}]="${targetUser}"
            fi
            if [[ "${mode}" == "l" ]]; then
              targetPathUserList+=("${targetPath}")
            fi
          else
            echo "No need to prepare source path: ${volumeSourcePath}"
          fi
        elif [[ "${mode}" == "o" ]]; then
          user=$(containerCommandQuiet "${containerName}" "stat -L -c \"%U\" ${targetPath}")
          if [[ "${user}" != "${targetUser}" ]]; then
            echo "Changing owner of path: ${targetPath} to: ${targetUser}"
            containerCommand "${containerName}" "chown ${targetUser}: ${targetPath}"
          else
            echo "No need to change owner of path: ${targetPath} to: ${targetUser}"
          fi
        fi
      else
        >&2 echo "Source path meta file does not exist: ${volumeSourcePath}"
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

    for targetPath in "${targetPathUserList[@]}"; do
      targetPathGroupId=$(containerCommandQuiet "${containerName}" "stat -L -c \"%g\" ${targetPath}")
      targetPathGroupName=$(containerCommandQuiet "${containerName}" "getent group ${targetPathGroupId} | tr ':' ' ' | awk '{print \$1}'")
      targetPathGroupName=$(prepareValue "${targetPathGroupName}")

      if [[ -z "${targetPathGroupName}" ]]; then
        groupName="docker_volume_${targetPathGroupId}"
        echo "Creating new group: ${groupName}"
        containerCommand "${containerName}" "groupadd -g ${targetPathGroupId} ${groupName}"
      else
        echo "No need to create group: ${groupName}"
      fi

      targetPathUserId=$(containerCommandQuiet "${containerName}" "stat -L -c \"%u\" ${targetPath}")
      targetPathUserName=$(containerCommandQuiet "${containerName}" "getent passwd ${targetPathUserId} | cat" | tr ':' ' ' | awk '{print $1}')
      targetPathUserName=$(prepareValue "${targetPathUserName}")

      if [[ -z "${targetPathUserName}" ]]; then
        userName="docker_volume_${targetPathUserId}"
        echo "Creating new user: ${userName}"
        containerCommand "${containerName}" "useradd -m -u ${targetPathUserId} -g ${targetPathGroupId} ${userName}"
      else
        echo "No need to create user: ${targetUser}"
      fi
    done
  else
    echo "Not possible to prepare volumes of container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumePrepare
