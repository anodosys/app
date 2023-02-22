#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageCheckRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  local useTokenFile
  local tokenFile
  local tokenTime
  local token
  local localData
  local remoteData
  local localId
  local remoteId
  local localTimestamp
  local lastPushedTimestamps
  local remoteTimestamp

  if [[ "${imageName}" =~ '/' ]]; then
    remoteImageName="${imageName}"
  else
    remoteImageName="library/${imageName}"
  fi

  localData=
  remoteData=
  tokenFile=

  localData=$(docker image inspect --format '{{ json . }}' "${imageName}:${imageTag}")

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
    remoteData=$(curl -s "https://hub.docker.com/v2/repositories/${remoteImageName}/tags/${imageTag}/" | cat)
  elif [[ -n "${userName}" ]] && [[ -n "${password}" ]] && [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
    useTokenFile=0
    mkdir -p "${anodosysUserVarPath}/auth"
    tokenFile="${anodosysUserVarPath}/auth/hub_docker_com"
    if [[ -f "${tokenFile}" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
      if [[ "${tokenTime}" -lt 55 ]]; then
        useTokenFile=1
      fi
    fi

    if [[ "${useTokenFile}" == 1 ]]; then
      token=$(cat "${tokenFile}")
    else
      token=$(curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"${userName}\",\"password\":\"${password}\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token)
      echo -n "${token}" > "${tokenFile}"
    fi

    remoteData=$(curl -s -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${remoteImageName}/tags/${imageTag}/" | cat)
  fi

  if [[ -n "${remoteData}" ]]; then
    error=$(echo "${remoteData}" | jq -r '.error //empty')
    if [[ "${error}" == "true" ]]; then
      >&2 echo "Could not check remote image ${imageName}:${imageTag} because: $(echo "${remoteData}" | jq -r '.detail //empty')"
      exit 1
    else
      if [[ -n "${tokenFile}" ]]; then
        touch "${tokenFile}"
      fi
    fi

    localId=$(echo "${localData}" | jq -r '.RepoDigests[]')
    localId="${localId##*@}"

    remoteId=$(echo "${remoteData}" | jq -r '.digest //empty')
    if [[ -z "${remoteId}" ]]; then
      remoteId=$(echo "${remoteData}" | jq -r '.images[] .digest //empty')
    fi

    if [[ "${localId}" != "${remoteId}" ]]; then
      localTimestamp=$(date -d "$(echo "${localData}" | jq -r '.Created')" +%s)
      lastPushedTimestamps=( $(echo "${remoteData}" | jq -r '.images[] .last_pushed' | sort -r) )
      remoteTimestamp=$(date -d "${lastPushedTimestamps[0]}" +%s)
      if [[ "${remoteTimestamp}" -gt "${localTimestamp}" ]]; then
        echo 2
      fi
    else
      echo 1
    fi
  else
    echo 0
  fi
}

# shellcheck disable=SC2034
typeset -fx imageCheckRemote
