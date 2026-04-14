#!/bin/bash -e

imageUsed()
{
  local imageName="${1}"
  local imageTag="${2}"

  if [[ $(imageUsedByContainer "${imageName,,}" "${imageTag,,}") == 0 ]] && [[ $(imageUsedByImage "${imageName,,}" "${imageTag,,}") == 0 ]]; then
    echo "0"
  else
    echo "1"
  fi
}

# shellcheck disable=SC2034
typeset -fx imageUsed

imageUsedByContainer()
{
  local imageName="${1}"
  local imageTag="${2}"
  local imageId
  local imageFullId
  local containerIds

  if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 1 ]]; then
    if [[ -n "${imageTag}" ]]; then
      imageId=$(imageId "${imageName,,}" "${imageTag,,}")
      imageFullId=$(docker image inspect --format '{{.Id}}' "${imageName,,}:${imageTag,,}")
    else
      imageFullId=$(docker image inspect --format '{{.Id}}' "${imageName,,}")
    fi

    containerIds=( $(docker container ls -aq) )
    if [[ "${#containerIds[@]}" -gt 0 ]]; then
      for containerId in "${containerIds[@]}"; do
        if [[ $(docker container inspect "${containerId}" --format "{{ if eq .Image \"${imageFullId}\" }}{{.Id}}{{end}}" | grep -v '^$' | wc -l) -gt 0 ]]; then
          echo "${containerId}"
          exit 0
        fi
      done
    fi
  fi

  echo "0"
}

# shellcheck disable=SC2034
typeset -fx imageUsedByContainer

imageUsedByImage()
{
  local imageName="${1}"
  local imageTag="${2}"
  local imageId
  local imageIds
  local nextImageId
  local historyImageId

  if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 1 ]]; then
    if [[ -n "${imageTag}" ]]; then
      imageId=$(imageId "${imageName,,}" "${imageTag,,}")
    else
      imageId="${imageName,,}"
    fi

    imageIds=( $(docker images --all --format "{{.ID}}") )
    if [[ "${#imageIds[@]}" -gt 0 ]]; then
      for nextImageId in "${imageIds[@]}"; do
        if [[ "${nextImageId}" != "${imageId}" ]]; then
          for historyImageId in $(docker image history "${nextImageId}" | awk '{print $1}'); do
            if [[ "${historyImageId}" == "${imageId}" ]]; then
              echo "${nextImageId}"
              exit 0
            fi
          done
        fi
      done
    fi
  fi

  echo "0"
}

# shellcheck disable=SC2034
typeset -fx imageUsedByImage
