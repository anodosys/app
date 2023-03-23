#!/bin/bash -e

if [[ -z "${anodosysUserVarVolumePath}" ]]; then
  >&2 echo "No anodosys user var volume path defined"
  exit 1
fi

containerVolumeCheck()
{
  local containerName="${1}"
  local volumeSourcePaths
  local volumeSourcePath
  local volumeMetadataFilePath
  local sourcePath
  local targetPath
  local targetUser
  local mode
  local empty
  local user
  local accessRights

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeSourcePaths=( $(containerVolumeSourcePathList "${containerName}" ) )
    IFS="${oldIFS}"

    for volumeSourcePath in "${volumeSourcePaths[@]}"; do
      volumeSourcePath=$(trim "${volumeSourcePath}")
      volumeMetadataFilePath=$(volumeMetadataFilePath "${volumeSourcePath}")

      if [[ -f "${volumeMetadataFilePath}" ]]; then
        #echo "Checking source path: ${volumeSourcePath}"

        sourcePath=$(volumeMetadataGet "${volumeSourcePath}" "sourcePath")
        targetPath=$(volumeMetadataGet "${volumeSourcePath}" "targetPath")
        targetUser=$(volumeMetadataGet "${volumeSourcePath}" "targetUser")
        mode=$(volumeMetadataGet "${volumeSourcePath}" "mode")

        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${targetUser}" != "local" ]]; then
          empty=$(volumeMetadataGet "${volumeSourcePath}" "empty")

          if [[ -n "${sourcePath}" ]] && [[ "${empty}" == "true" ]]; then
            user=$(volumeMetadataGet "${volumeSourcePath}" "user")
            accessRights=$(volumeMetadataGet "${volumeSourcePath}" "accessRights")
          else
            user=$(stat -L -c "%U" "${sourcePath}")
            accessRights=$(stat -L -c "%a" "${sourcePath}")
          fi

          if [[ "${user}" != "${targetUser}" ]]; then
            if [[ "${mode}" == "r" ]]; then
              if [[ "${accessRights:1:1}" != 4 ]] && [[ "${accessRights:1:1}" != 5 ]] && [[ "${accessRights:1:1}" != 6 ]] && [[ "${accessRights:1:1}" != 7 ]]; then
                >&2 echo "Source path: ${sourcePath} has different user: ${user} than target user: ${targetUser} and is not readable for group"
                exit 1
              else
                echo "Source path: ${sourcePath} has different user: ${user} than target user: ${targetUser} and is readable for group"
              fi
            elif [[ "${mode}" == "w" ]]; then
              if [[ "${accessRights:1:1}" != 2 ]] && [[ "${accessRights:1:1}" != 3 ]] && [[ "${accessRights:1:1}" != 6 ]] && [[ "${accessRights:1:1}" != 7 ]]; then
                >&2 echo "Source path: ${sourcePath} has different user: ${user} than target user: ${targetUser} and is not writable for group"
                exit 1
              else
                echo "Source path: ${sourcePath} has different user: ${user} than target user: ${targetUser} and is writable for group"
              fi
            elif [[ "${mode}" == "o" ]]; then
              echo "Source path: ${sourcePath} has different user: ${user} than target user: ${targetUser} and is required to be owned by target user"
            else
              >&2 echo "Unknown volume mode: ${mode} to mount source path: ${sourcePath} to target path: ${targetPath}"
              exit 1
            fi
          else
            echo "No different user for source path: ${volumeSourcePath}"
          fi
        else
          echo "No need to check source path: ${volumeSourcePath}"
        fi
      else
        >&2 echo "Source path meta file does not exist: ${volumeSourcePath}"
        exit 1
      fi
    done
  else
    echo "Not possible to check volumes of container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumeCheck
