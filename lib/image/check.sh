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
  local tokenTime
  local token
  local localId
  local remoteId

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
    if [[ -f "${anodosysUserVarPath}/image-check-token" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${anodosysUserVarPath}/image-check-token")")
      if [[ "${tokenTime}" -gt 55 ]]; then
        rm -rf "${anodosysUserVarPath}/image-check-token"
      fi
    fi
    if [[ -f "${anodosysUserVarPath}/image-check-token" ]]; then
      token=$(cat "${anodosysUserVarPath}/image-check-token")
    else
      token=$(curl -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"${userName}\",\"password\":\"${password}\"}" "https://hub.docker.com/v2/users/login/" | jq -r .token)
      echo -n "${token}" > "${anodosysUserVarPath}/image-check-token"
    fi
    localId=$(docker image inspect --format '{{ json . }}' "${imageName}:${imageTag}" | jq -r '.RepoDigests[]')
    localId="${localId##*@}"
    remoteId=$(curl -s -H "Authorization: JWT ${token}" "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" | jq -r '.images[] .digest')
    if [[ "${localId}" != "${remoteId}" ]]; then
      echo 1
      exit 0
    fi
  fi
  echo 0
}

# shellcheck disable=SC2034
typeset -fx imageCheckRemote
