#!/bin/bash -e

imageCheck()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  if [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Getting access token for user: ${userName}"
    token=$(curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"${userName}\",\"password\":\"${password}\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token)
    echo "Getting local image id: ${imageName}:${imageTag}"
    localId=$(docker image inspect --format '{{ json . }}' "${imageName}:${imageTag}" | jq -r '.RepoDigests[]')
    localId="${localId##*@}"
    echo "Getting remote image id: ${imageName}:${imageTag}"
    remoteId=$(curl -s -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" | jq -r '.images[] .digest')
    if [[ "${localId}" != "${remoteId}" ]]; then
      echo 1
      exit 0
    fi
  fi
  echo 0
}

# shellcheck disable=SC2034
typeset -fx imageCheck
