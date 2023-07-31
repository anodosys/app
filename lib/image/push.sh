#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

imagePush()
{
  local imageName="${1}"
  local imageTag="${2}"

  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    pushErrorFileName="${anodosysUserVarPath}/push/${imageName}_${imageTag}.err"
    mkdir -p "$(dirname "${pushErrorFileName}")"

    echo "Pushing image: ${imageName}:${imageTag}"
    exec >/dev/tty
    exec 2>/dev/tty
    logDisable
    set +e
    docker push "${imageName}:${imageTag}" 2>"${pushErrorFileName}"
    pushResult=$?
    set -e
    if [[ "${pushResult}" -gt 0 ]]; then
      pushResultMessage=$(cat "${pushErrorFileName}")
      if [[ "${pushResultMessage}" == "denied: requested access to the resource is denied" ]]; then
        echo "Please specify the user name to the repository, followed by [ENTER]:"
        read -r repositoryUserName
        echo "Please specify the password to the repository, followed by [ENTER]:"
        read -r repositoryPassword
        echo "${repositoryPassword}" | docker login --username "${repositoryUserName}" --password-stdin
        docker push "${imageName}:${imageTag}"
      fi
    fi
    logEnable
  else
    >&2 echo "Image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx imagePush
