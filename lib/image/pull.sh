#!/bin/bash -e

imagePull()
{
  local imageName="${1}"
  local imageTag="${2}"
  local force="${3:-no}"
  local userName="${4}"
  local password="${5}"
  local currentUserName

  if [[ "${force}" == "yes" ]] || [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 0 ]]; then
    echo "Pulling image: ${imageName,,}:${imageTag,,}"
    logDisable
    if [[ -n "${userName}" ]] && [[ -n "${password}" ]]; then
      currentUserName=$("docker-credential-$(jq -r .credsStore ~/.docker/config.json)" list | jq -r '. | to_entries[] | select(.key | contains("docker.io")) | last(.value)')
      if [[ "${currentUserName}" != "${userName}" ]]; then
        echo "Logging in user: ${userName}"
        echo "${password}" | docker login -u="${userName}" --password-stdin
      fi
    fi
    # containerPlatform (server config, e.g. linux/arm64) pulls an image for another architecture, run with QEMU
    if [[ -n "${containerPlatform}" ]] && [[ "${containerPlatform}" != "-" ]]; then
      docker pull --platform "${containerPlatform}" "${imageName,,}:${imageTag,,}"
    else
      docker pull "${imageName,,}:${imageTag,,}"
    fi
    logEnable
  else
    echo "No need to pull image: ${imageName,,}:${imageTag,,}"
  fi
}

# shellcheck disable=SC2034
typeset -fx imagePull
