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
    if [[ -n "${imageId}" ]]; then
      containerIds=( $(docker container ls -aq) )
      if [[ "${#containerIds[@]}" -gt 0 ]]; then
        if [[ $(docker container inspect "${containerIds[@]}" --format "{{ if eq .Image \"${imageId}\" }}{{.Id}}{{end}}" | grep -v '^$' | wc -l) -gt 0 ]]; then
          echo "1"
          exit 0
        fi
      fi
    else
      imageIds=( $(docker image ls -a | tail -n +2 | awk '{print $3}') )
      if [[ "${#imageIds[@]}" -gt 0 ]]; then
        if [[ $(for nextImageId in "${imageIds[@]}"; do if [[ "${nextImageId}" != "${imageId}" ]]; then for historyImageId in $(docker image history "${nextImageId}" | awk '{print $1}'); do if [[ "${historyImageId}" == "${imageId}" ]]; then echo "${nextImageId}"; fi; done; fi; done | wc -l) -gt 0 ]]; then
          echo "1"
          exit 0
        fi
      fi
    fi
  fi
  echo "0"
}

# shellcheck disable=SC2034
typeset -fx imageUsed
