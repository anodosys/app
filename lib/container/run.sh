#!/bin/bash -e

containerRun()
{
  local imageName="${1}"
  shift
  local containerName="${1}"
  shift
  local systemName="${1}"
  shift
  local serverName="${1}"
  shift
  local useNamedVolumes="${1}"
  shift
  local containerCommand="${1}"
  shift
  local parameters=("$@")

  if [[ $(containerRunning "${containerName}") == 0 ]]; then
    command="docker run -itd --label \"com.docker.compose.project=${systemName}\" --label \"com.docker.compose.service=${serverName}\" --network \"${systemName}\""

    for parameter in "${parameters[@]}"; do
      if [[ "${parameter:0:6}" == "alias:" ]]; then
        command+=" --network-alias \"${parameter:6}\""
      elif [[ "${parameter:0:5}" == "port:" ]]; then
        command+=" --publish ${parameter:5}"
      elif [[ "${parameter:0:7}" == "expose:" ]]; then
        command+=" --expose ${parameter:7}"
      elif [[ "${parameter:0:7}" == "volume:" ]]; then
        readarray -d : -t parameterParts < <(printf '%s' "${parameter:7}")
        sourcePath="${parameterParts[0]}"
        targetPath="${parameterParts[1]}"
        targetUser=$(getArrayValue 2 "me" "${parameterParts[@]}")
        mode=$(getArrayValue 3 "r" "${parameterParts[@]}")
        userId=$(getArrayValue 4 "-" "${parameterParts[@]}")
        user=$(getArrayValue 5 "-" "${parameterParts[@]}")
        groupId=$(getArrayValue 6 "-" "${parameterParts[@]}")
        group=$(getArrayValue 7 "-" "${parameterParts[@]}")
        rights=$(getArrayValue 8 "-" "${parameterParts[@]}")
        empty=$(getArrayValue 9 "-" "${parameterParts[@]}")
        if [[ ! -e "${sourcePath}" ]]; then
          echo "Creating container source path: ${sourcePath}"
          mkdir -p "${sourcePath}" | cat
          if [[ -d "${sourcePath}" ]]; then
            echo "Successfully created source path: ${sourcePath}" | sed $'s,.*,\e[1;36m&\e[m,'
            chmod 0775 "${sourcePath}"
            if [[ $(stat -c '%a' "${sourcePath}") == "775" ]]; then
              echo "Successfully changed access rights of source path: ${sourcePath} to 0775" | sed $'s,.*,\e[1;36m&\e[m,'
            else
              >&2 echo "Could not change access rights of source path: ${sourcePath} to 0775"
              exit 1
            fi
          else
            >&2 echo "Could not create source path: ${sourcePath}"
            exit 1
          fi
        fi
        if [[ ! -e "${sourcePath}" ]]; then
          >&2 echo "Source path does not exist: ${sourcePath}"
          exit 1
        fi
        sourcePath=$(realpath "${sourcePath}")
        containerVolumeCreate "${containerName}" "${useNamedVolumes}" "${sourcePath}" "${targetPath}" "${targetUser}" "${mode}" "${userId}" "${user}" "${groupId}" "${group}" "${rights}" "${empty}"
        if [[ "${useNamedVolumes}" == "true" ]]; then
          sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
          volumeName="${containerName}_${sourceName}"
          command+=" --mount source=${volumeName},destination=${targetPath}"
        else
          command+=" --volume=${sourcePath}:${targetPath}"
        fi
      elif [[ "${parameter:0:12}" == "environment:" ]]; then
        command+=" --env ${parameter:12}"
      elif [[ "${parameter:0:5}" == "size:" ]]; then
        command+=" --storage-opt size=${parameter:5}"
      fi
    done

    command+=" --name \"${containerName}\" \"${imageName,,}\""

    if [[ -n "${containerCommand}" ]] && [[ "${containerCommand}" != "-" ]]; then
      echo "Running container: ${containerName} with command: ${containerCommand}"
      command+=" ${containerCommand}"
    else
      echo "Running container: ${containerName}"
    fi

    bash -c "${command}" 2>&1 | cat

    containerHostNameAdd "${containerName}"
  else
    echo "No need to start container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRun
