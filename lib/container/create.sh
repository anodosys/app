#!/bin/bash -e

containerCreate()
{
  local imageName="${1}"
  shift
  local containerName="${1}"
  shift
  local networkName="${1}"
  shift
  local parameters=("$@")
  local command
  local sourcePath
  local targetPath
  local targetUser
  local mode
  local sourceName
  local volumeName
  local result

  if [[ $(containerRunning "${containerName}") == 0 ]] && [[ $(containerExists "${containerName}") == 0 ]]; then
    command="docker create --tty --network \"${networkName}\""
    for parameter in "${parameters[@]}"; do
      if [[ "${parameter:0:11}" == "entryPoint:" ]]; then
        command+=" --entrypoint \"${parameter:11}\""
      elif [[ "${parameter:0:6}" == "alias:" ]]; then
        command+=" --network-alias \"${parameter:6}\""
      elif [[ "${parameter:0:5}" == "port:" ]]; then
        command+=" --publish ${parameter:5}"
      elif [[ "${parameter:0:7}" == "expose:" ]]; then
        command+=" --expose ${parameter:7}"
      elif [[ "${parameter:0:7}" == "volume:" ]]; then
        readarray -d : -t parameterParts < <(printf '%s' "${parameter:7}")
        sourcePath="${parameterParts[0]}"
        targetPath="${parameterParts[1]}"
        if test "${parameterParts[2]+isset}"; then
          targetUser="${parameterParts[2]}"
          if [[ -z "${targetUser}" ]]; then
            targetUser="local"
          fi
        else
          targetUser="local"
        fi
        if test "${parameterParts[3]+isset}"; then
          mode="${parameterParts[3]}"
          if [[ -z "${mode}" ]]; then
            mode="r"
          fi
        else
          mode="r"
        fi
        if [[ ! -e "${sourcePath}" ]]; then
          echo "Creating source path: ${sourcePath}"
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
        containerVolumeCreate "${containerName}" "${sourcePath}" "${targetPath}" "${targetUser}" "${mode}"
        sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
        volumeName="${containerName}_${sourceName}"
        command+=" --mount source=${volumeName},destination=${targetPath}"
      fi
    done
    command+=" --name \"${containerName}\" \"${imageName}\""
    echo "Creating container: ${containerName} with image: ${imageName}"
    result=$(bash -c "${command}" 2>&1 | cat)
    if [[ $(containerExists "${containerName}") == 1 ]]; then
      echo "Successfully created container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create container: ${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCreate
