#!/bin/bash -e

imageUsed()
{
  local imageName="${1}"
  local imageTag="${2}"
  local imageId
  local nextImageId
  local historyImageId
  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    imageId=$(docker image inspect --format '{{.Id}}' "${imageName}:${imageTag}")
    # shellcheck disable=SC2046
    if [[ -n "${imageId}" ]] && [[ $(docker container inspect $(docker container ls -aq) --format "{{ if eq .Image \"${imageId}\" }}{{.Id}}{{end}}" | grep -v '^$' | wc -l) -gt 0 ]]; then
      echo "1"
      exit 0
    else
      if [[ $(for nextImageId in $(docker image ls -a | tail -n +2 | awk '{print $3}'); do if [[ "${nextImageId}" != "${imageId}" ]]; then for historyImageId in $(docker image history "${nextImageId}" | awk '{print $1}'); do if [[ "${historyImageId}" == "${imageId}" ]]; then echo "${nextImageId}"; fi; done; fi; done | wc -l) -gt 0 ]]; then
        echo "1"
        exit 0
      fi
    fi
  fi
  echo "0"
}

# shellcheck disable=SC2034
typeset -fx imageUsed
