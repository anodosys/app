#!/bin/bash -e

imageCreate()
{
  local imageName="${1}"
  local imageTag="${2}"
  local containerName="${3}"
  local buildImageEntryPoint="${4}"
  local buildImageUser="${5}"
  local buildImageCommand="${6}"
  local command
  local result

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    echo "Creating image: ${imageName,,}:${imageTag,,} from container: ${containerName}"
    command="docker commit"
    if [[ -n "${buildImageEntryPoint}" ]] && [[ "${buildImageEntryPoint}" != "-" ]]; then
      if [[ "${buildImageEntryPoint}" =~ "," ]]; then
        # shellcheck disable=SC2206
        buildImageEntryPointParts=( ${buildImageEntryPoint//,/ } )
        buildImageEntryPoint="$( printf "\\\\\",\\\\\"%s" "${buildImageEntryPointParts[@]}" | cut -c 6- )"
      fi
      command+=" --change=\"ENTRYPOINT [\\\"${buildImageEntryPoint}\\\"]\""
    fi
    if [[ -n "${buildImageUser}" ]] && [[ "${buildImageUser}" != "-" ]]; then
      command+=" --change=\"USER ${buildImageUser}\""
    fi
    if [[ -n "${buildImageCommand}" ]] && [[ "${buildImageCommand}" != "-" ]]; then
      if [[ "${buildImageCommand}" =~ "," ]]; then
        # shellcheck disable=SC2206
        buildImageCommandParts=( ${buildImageCommand//,/ } )
        buildImageCommand="$( printf "\\\\\",\\\\\"%s" "${buildImageCommandParts[@]}" | cut -c 6- )"
      fi
      command+=" --change=\"CMD [\\\"${buildImageCommand}\\\"]\""
    fi
    command+=" \"${containerName}\" \"${imageName,,}:${imageTag,,}\""
    echo "Image command: ${command}"
    result=$(bash -c "${command}" 2>&1 | cat)
    if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 1 ]]; then
      echo "Successfully created image: ${imageName,,}:${imageTag,,}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create image: ${imageName,,}:${imageTag,,}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    >&2 echo "Container does not exist: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx imageCreate
