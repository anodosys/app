#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageRemove()
{
  local imageName="${1}"
  local imageTag="${2}"
  local checkUsed="${3:-error}"
  local result

  if [[ -z "${imageTag}" ]] || [[ "${imageTag}" == "-" ]]; then
    if [[ $(imageExists "${imageName}") == 1 ]]; then
      if [[ "${checkUsed}" == "no" ]] || [[ $(imageUsed "${imageName}") == 0 ]]; then
        echo "Removing image: ${imageName}"
        result=$(docker image rm "${imageName}" 2>&1 | cat)
        if [[ $(imageExists "${imageName}") == 0 ]]; then
          echo "Successfully removed image: ${imageName}" | sed $'s,.*,\e[0;32m&\e[m,'
        else
          >&2 echo "Could not remove image: ${imageName}"
          >&2 echo "${result}"
          exit 1
        fi
      else
        if [[ "${checkUsed}" == "error" ]]; then
          >&2 echo "Could not remove image: ${imageName} because it is in use"
          exit 1
        elif [[ "${checkUsed}" == "warn" ]]; then
          echo "Could not remove image: ${imageName} because it is in use" | sed $'s,.*,\e[0;33m&\e[m,'
          exit 0
        fi
      fi
    else
      echo "No need to remove image: ${imageName}"
    fi
  else
    if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
      if [[ "${checkUsed}" == "no" ]] || [[ $(imageUsed "${imageName}" "${imageTag}") == 0 ]]; then
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
        if [[ "${checkUsed}" == "error" ]]; then
          >&2 echo "Could not remove image: ${imageName}:${imageTag} because it is in use"
          exit 1
        elif [[ "${checkUsed}" == "warn" ]]; then
          echo "Could not remove image: ${imageName}:${imageTag} because it is in use" | sed $'s,.*,\e[0;33m&\e[m,'
          exit 0
        fi
      fi
    else
      echo "No need to remove image: ${imageName}:${imageTag}"
    fi
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
  local retry="${5:-no}"
  local useTokenFile
  local tokenFile
  local tokenTime
  local token
  local remoteData

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
    useTokenFile=0

    mkdir -p "${anodosysUserVarPath}/auth"
    tokenFile="${anodosysUserVarPath}/auth/hub_docker_com"

    if [[ "${retry}" == "no" ]]; then
      if [[ -f "${tokenFile}" ]]; then
        tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
        if [[ "${tokenTime}" -lt 55 ]]; then
          useTokenFile=1
        fi
      fi
    fi

    if [[ "${useTokenFile}" == 1 ]]; then
      token=$(cat "${tokenFile}")
    elif [[ -n "${userName}" ]] && [[ -n "${password}" ]]; then
      token=$(curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"${userName}\",\"password\":\"${password}\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token)
      echo -n "${token}" > "${tokenFile}"
    else
      token=
    fi

    echo "Removing remote image: ${imageName}:${imageTag}"

    logDisable
    if [[ -n "${token}" ]]; then
      remoteData=$(curl -s -X DELETE -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" 2>&1 | cat)
    else
      remoteData=$(curl -s -X DELETE "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" 2>&1 | cat)
    fi
    logEnable

    if [[ -z "${remoteData}" ]]; then
      if [[ -n "${token}" ]]; then
        touch "${tokenFile}"
      fi
      echo "Successfully removed remote image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      reason=$(echo "${remoteData}" | jq -r '.detail //empty')
      if [[ -z "${reason}" ]]; then
        reason=$(echo "${remoteData}" | jq -r '.message //empty')
      fi
      if [[ "${retry}" == "no" ]] && [[ "${reason}" == "unauthorized" ]]; then
        echo "Please specify the user name to the repository, followed by [ENTER]:"
        read -r userName < /dev/tty
        echo "Please specify the password to the repository, followed by [ENTER]:"
        read -r password < /dev/tty
        imageRemoveRemote "${imageName}" "${imageTag}" "${userName}" "${password}" "yes"
      else
        >&2 echo "Could not remove remote image ${imageName}:${imageTag} because: ${reason}"
        exit 1
      fi
    fi
  else
    echo "No need to remove remote image: ${imageName}:${imageTag}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageRemoveRemote
