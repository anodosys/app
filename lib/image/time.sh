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

  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    date --date="$(docker image inspect -f "{{ .Created }}" "${imageName}:${imageTag}")" "+${format}"
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
  local tokenFile
  local tokenTime
  local token
  local time

  if [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${userName}" "${password}") == 1 ]]; then
    mkdir -p "${anodosysUserVarPath}/auth"
    tokenFile="${anodosysUserVarPath}/auth/docker_io_$(echo "${imageName}" | sed 's/[^[:alnum:]]/_/g')"
    if [[ -f "${tokenFile}" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
      if [[ "${tokenTime}" -gt 295 ]]; then
        rm -rf "${tokenFile}"
      fi
    fi

    if [[ -f "${tokenFile}" ]]; then
      token=$(cat "${tokenFile}")
    else
      token=$(curl -s --user "${userName}:${password}" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${imageName}:pull" | jq -r '.token')
      echo -n "${token}" > "${tokenFile}"
    fi

    time=$(curl -s -X GET -H "Authorization:Bearer ${token}" "https://registry-1.docker.io/v2/${imageName}/manifests/${imageTag}" | jq -r '.history[].v1Compatibility' | jq '.created' | sort | tail -n1)
    time=$(prepareValue "${time}")
    date --date="${time}" "+${format}"
    touch "${tokenFile}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageTimeRemote
