#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageRemove()
{
  local imageName="${1}"
  local imageTag="${2}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    if [[ $(imageUsed "${imageName}" "${imageTag}") == 0 ]]; then
      echo "Removing image: ${imageName}:${imageTag}"
      result=$(docker image rm "${imageName}:${imageTag}" 2>&1 | cat)
      if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
        echo "Successfully removed image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
      else
        >&2 echo "Could not remove image: ${imageName}:${imageTag}"
        >&2 echo "${result}"
        exit 1
      fi
    else
      >&2 echo "Could not remove image: ${imageName}:${imageTag} because it is in use"
      exit 1
    fi
  else
    echo "No need to remove image: ${imageName}:${imageTag}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageRemove

imageRemoveRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  local token
  local result

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
    tokenFile="${anodosysUserVarPath}/hub_docker_com"
    if [[ -f "${tokenFile}" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
      if [[ "${tokenTime}" -gt 55 ]]; then
        rm -rf "${tokenFile}"
      fi
    fi

    if [[ -f "${tokenFile}" ]]; then
      token=$(cat "${tokenFile}")
    else
      token=$(curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"${userName}\",\"password\":\"${password}\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token)
      echo -n "${token}" > "${tokenFile}"
    fi

    echo "Removing remote image: ${imageName}:${imageTag}"

    logDisable
    result=$(curl -s -X DELETE -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" 2>&1 | cat)
    logEnable

    if [[ -z "${result}" ]]; then
      echo "Successfully removed remote image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove remote image: ${imageName}:${imageTag}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove remote image: ${imageName}:${imageTag}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageRemoveRemote
