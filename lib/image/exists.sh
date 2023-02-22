#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imageExists()
{
  local imageName="${1}"
  local imageTag="${2}"

  imageName=$(echo "${imageName}" | sed 's/^library\///')

  if [[ -n "${imageTag}" ]]; then
    docker image ls -a | grep -E "^${imageName}\\s+${imageTag}\\s" | wc -l
  else
    docker image ls -a | awk '{print $3}' | grep -E "^${imageName}$" | wc -l
  fi
}

# shellcheck disable=SC2034
typeset -fx imageExists

imageExistsRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  local userName="${3}"
  local password="${4}"
  local status
  local useTokenFile
  local tokenFile
  local tokenTime
  local token

  if ! [[ "${imageName}" =~ '/' ]]; then
    imageName="library/${imageName}"
  fi

  status=$(curl -s -w "%{http_code}" -o /dev/null "https://hub.docker.com/v2/repositories/${imageName}/tags/${imageTag}/" | cat)
  if [[ "${status}" == 200 ]]; then
    echo 1
  elif [[ -n "${userName}" ]] && [[ -n "${password}" ]]; then
    useTokenFile=0
    mkdir -p "${anodosysUserVarPath}/auth"
    tokenFile="${anodosysUserVarPath}/auth/docker_io_$(echo "${imageName}" | sed 's/[^[:alnum:]]/_/g')"
    if [[ -f "${tokenFile}" ]]; then
      tokenTime=$(expr "$(date +%s)" - "$(stat -c %Y "${tokenFile}")")
      if [[ "${tokenTime}" -lt 55 ]]; then
        useTokenFile=1
      fi
    fi

    if [[ "${useTokenFile}" == 1 ]]; then
      token=$(cat "${tokenFile}")
    else
      token=$(curl -s --user "${userName}:${password}" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${imageName}:pull" | jq -r '.token')
      echo -n "${token}" > "${tokenFile}"
    fi

    status=$(curl -s -w "%{http_code}" -o /dev/null -X GET -H "Authorization:Bearer ${token}" "https://registry-1.docker.io/v2/${imageName}/manifests/${imageTag}" | cat)
    if [[ "${status}" == 401 ]]; then
      >&2 echo "Could not check remote image ${imageName}:${imageTag} exits because: unauthorized"
      exit 1
    else
      touch "${tokenFile}"
    fi

    if [[ "${status}" == 200 ]]; then
      echo 1
    else
      echo 0
    fi
  else
    echo 0
  fi
}

# shellcheck disable=SC2034
typeset -fx imageExistsRemote
