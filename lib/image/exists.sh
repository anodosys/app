#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageExists()
{
  local imageName="${1}"
  local imageTag="${2}"

  docker images | grep -E "^${imageName}\\s+${imageTag}\\s" | wc -l
}

# shellcheck disable=SC2034
typeset -fx imageExists

imageExistsRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  local useTokenFile
  local tokenFile
  local tokenTime
  local token
  local status

  useTokenFile=0
  mkdir -p "${anodosysUserVarPath}/auth"
  tokenFile="${anodosysUserVarPath}/auth/docker_io_$(echo "${imageName}" | sed 's/[^[:alnum:]]/_/g')"
  if [[ -f "${tokenFile}" ]]; then
    tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
    if [[ "${tokenTime}" -gt 295 ]]; then
      useTokenFile=1
    fi
  fi

  if [[ "${useTokenFile}" == 1 ]]; then
    token=$(cat "${tokenFile}")
  else
    token=$(curl -s --user "${userName}:${password}" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${imageName}:pull" | jq -r '.token')
    echo -n "${token}" > "${tokenFile}"
  fi

  status=$(curl -s -w "%{http_code}" -o /dev/null -X GET -H "Authorization:Bearer ${token}" "https://registry-1.docker.io/v2/${imageName}/manifests/${imageTag}")
  touch "${tokenFile}"

  if [[ "${status}" == 200 ]]; then
    echo 1
  else
    echo 0
  fi
}

# shellcheck disable=SC2034
typeset -fx imageExistsRemote
