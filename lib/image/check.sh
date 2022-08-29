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
  local remoteData
  local localId
  local remoteId
  local localTimestamp
  local remoteTimestamp

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
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

    localId=$(docker image inspect --format '{{ json . }}' "${imageName}:${imageTag}" | jq -r '.RepoDigests[]')
    localId="${localId##*@}"

    remoteData=$(curl -s -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/")
    touch "${tokenFile}"

    remoteId=$(echo "${remoteData}" | jq -r '.images[] .digest')
    if [[ "${localId}" != "${remoteId}" ]]; then
      localTimestamp=$(date -d "$(docker image inspect --format '{{ json . }}' "${imageName}:${imageTag}" | jq -r '.Created')" +%s)
      remoteTimestamp=$(date -d "$(echo "${remoteData}" | jq -r '.images[] .last_pushed')" +%s)
      if [[ "${remoteTimestamp}" -gt "${localTimestamp}" ]]; then
        echo 1
        exit 0
      fi
    fi
  fi
  echo 0
}

# shellcheck disable=SC2034
typeset -fx imageCheckRemote
