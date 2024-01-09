#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageTime()
{
  local imageName="${1}"
  local imageTag="${2}"
  local format="${3:-"%Y-%m-%d %H:%M:%S"}"

  if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 1 ]]; then
    date --date="$(docker image inspect -f "{{ .Created }}" "${imageName,,}:${imageTag,,}")" "+${format}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageTime

imageTimeRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  local format="${5:-"%Y-%m-%d %H:%M:%S"}"
  local useTokenFile
  local tokenFile
  local tokenTime
  local token
  local time

  if [[ $(imageExistsRemote "${imageName,,}" "${imageTag,,}" "${userName}" "${password}") == 1 ]]; then
    useTokenFile=0
    mkdir -p "${anodosysUserVarPath}/auth"
    tokenFile="${anodosysUserVarPath}/auth/docker_io_$(echo "${imageName,,}" | sed 's/[^[:alnum:]]/_/g')"
    if [[ -f "${tokenFile}" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
      if [[ "${tokenTime}" -lt 55 ]]; then
        useTokenFile=1
      fi
    fi

    if [[ "${useTokenFile}" == 1 ]]; then
      token=$(cat "${tokenFile}")
    else
      token=$(curl -s --user "${userName}:${password}" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${imageName,,}:pull" | jq -r '.token')
      echo -n "${token}" > "${tokenFile}"
    fi

    remoteData=$(curl -s -X GET -H "Authorization:Bearer ${token}" "https://registry-1.docker.io/v2/${imageName,,}/manifests/${imageTag,,}" | cat)
    errorCount=$(echo "${remoteData}" | jq -r '.errors | length')

    if [[ "${errorCount}" -eq 0 ]]; then
      time=$(echo "${remoteData}" | jq -r '.history[].v1Compatibility' | jq '.created' | sort | tail -n1)
      touch "${tokenFile}"
    else
      >&2 echo "Could not check creation time of remote image ${imageName,,}:${imageTag,,} because: $(echo "${remoteData}" | jq -r '.errors | .[] | .message')"
      exit 1
    fi

    time=$(prepareValue "${time}")
    date --date="${time}" "+${format}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageTimeRemote
