#!/bin/bash -e

containerVolumePrepare()
{
  local containerName="${1}"
  local volumeSourcePaths
  local volumeSourcePath
  local volumeMetadataFilePath
  local groupUserList
  local sourcePath
  local targetPath
  local empty
  local userId
  local groupId
  local rights
  local mode
  local targetUser
  local groupName
  local userNames
  local userNameList
  local result

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeSourcePaths=( $(containerVolumeSourcePathList "${containerName}" ) )
    IFS="${oldIFS}"

    declare -A groupUserList
    for volumeSourcePath in "${volumeSourcePaths[@]}"; do
      volumeSourcePath=$(trim "${volumeSourcePath}")
      volumeMetadataFilePath=$(volumeMetadataFilePath "${volumeSourcePath}")

      if [[ -f "${volumeMetadataFilePath}" ]]; then
        echo "Preparing source path: ${volumeSourcePath}"

        sourcePath=$(volumeMetadataGet "${volumeSourcePath}" "sourcePath")
        targetPath=$(volumeMetadataGet "${volumeSourcePath}" "targetPath")
        empty=$(volumeMetadataGet "${volumeSourcePath}" "empty")

        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${empty}" == "true" ]]; then
          userId=$(volumeMetadataGet "${volumeSourcePath}" "userId")
          groupId=$(volumeMetadataGet "${volumeSourcePath}" "groupId")
          rights=$(volumeMetadataGet "${volumeSourcePath}" "rights")
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

        targetUser=$(volumeMetadataGet "${volumeSourcePath}" "targetUser")
        mode=$(volumeMetadataGet "${volumeSourcePath}" "mode")

        if [[ "${mode}" == "r" ]] || [[ "${mode}" == "w" ]]; then
          if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ -n "${targetUser}" ]]; then
            groupId=$(stat -c '%g' "${sourcePath}")
            if test "${groupUserList[${groupId}]+isset}"; then
              groupUserList[${groupId}]+=",${targetUser}"
            else
              groupUserList[${groupId}]="${targetUser}"
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
  else
    echo "Not possible to prepare volumes of container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumePrepare
