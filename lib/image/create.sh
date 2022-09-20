#!/bin/bash -e

imageCreate()
{
  local imageName="${1}"
  local imageTag="${2}"
  local containerName="${3}"
  local buildImageEntryPoint="${4}"
  local result

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    echo "Creating image: ${imageName}:${imageTag} from container: ${containerName}"
    if [[ -n "${buildImageEntryPoint}" ]]; then
      result=$(docker commit --change="ENTRYPOINT ${buildImageEntryPoint}" "${containerName}" "${imageName}:${imageTag}" 2>&1 | cat)
    else
      result=$(docker commit "${containerName}" "${imageName}:${imageTag}" 2>&1 | cat)
    fi
    if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
      echo "Successfully created image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create image: ${imageName}:${imageTag}"
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
