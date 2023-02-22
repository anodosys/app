#!/bin/bash -e

containerVolumeCheck()
{
  local containerName="${1}"
  local volumeNames
  local volumeName
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
    volumeNames=( $(containerVolumeList "${containerName}" ) )
    IFS="${oldIFS}"

    for volumeName in "${volumeNames[@]}"; do
      volumeName=$(trim "${volumeName}")

      if [[ $(volumeExists "${volumeName}") == 1 ]]; then
        #echo "Checking volume: ${volumeName}"

        sourcePath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".sourcePath // empty")
        targetPath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetPath // empty")
        targetUser=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetUser // empty")
        mode=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".mode // empty")

        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${targetUser}" != "local" ]]; then
          empty=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".empty // empty")

          if [[ -n "${sourcePath}" ]] && [[ "${empty}" == "true" ]]; then
            user=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".user // empty")
            accessRights=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".rights // empty")
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
            echo "No different user for volume: ${volumeName}"
          fi
        else
          echo "No need to check volume: ${volumeName}"
        fi
      else
        >&2 echo "Volume does not exist: ${volumeName}"
        exit 1
      fi
    done
  else
    echo "Not possible to check volumes of container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumeCheck
