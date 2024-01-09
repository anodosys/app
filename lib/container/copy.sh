#!/bin/bash -e

containerCopy()
{
  local containerName="${1}"
  local localPath="${2}"
  local remotePath="${3}"
  local remoteUserName="${4}"
  local remoteGroupName="${5}"
  local remoteAccessRights="${6}"

  if [[ -z "${remotePath}" ]]; then
    remotePath=$(basename "${localPath}")
  fi

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Copying from: ${localPath} to container: ${containerName} at: ${remotePath}"
    docker cp "${localPath}" "${containerName}:${remotePath}"

    if [[ -n "${remoteUserName}" ]] && [[ "${remoteUserName}" != "-" ]]; then
      echo "Changing owner of: ${remotePath} to user: ${remoteUserName}"
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chown -R ${remoteUserName} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chown ${remoteUserName} ${remotePath}"
      fi
    fi

    if [[ -n "${remoteGroupName}" ]] && [[ "${remoteGroupName}" != "-" ]]; then
      echo "Changing owner of: ${remotePath} to group: ${remoteGroupName}"
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chgrp -R ${remoteGroupName} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chgrp ${remoteGroupName} ${remotePath}"
      fi
    fi

    if [[ -n "${remoteAccessRights}" ]] && [[ "${remoteAccessRights}" != "-" ]]; then
      echo "Changing access rights of: ${remotePath} to: ${remoteAccessRights}"
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chmod -R ${remoteAccessRights} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chmod ${remoteAccessRights} ${remotePath}"
      fi
    fi
  else
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCopy

containerCopyQuiet()
{
  local containerName="${1}"
  local localPath="${2}"
  local remotePath="${3}"
  local remoteUserName="${4}"
  local remoteGroupName="${5}"
  local remoteAccessRights="${6}"

  if [[ -z "${remotePath}" ]]; then
    remotePath=$(basename "${localPath}")
  fi

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    docker cp "${localPath}" "${containerName}:${remotePath}"

    if [[ -n "${remoteUserName}" ]] && [[ "${remoteUserName}" != "-" ]]; then
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chown -R ${remoteUserName} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chown ${remoteUserName} ${remotePath}"
      fi
    fi

    if [[ -n "${remoteGroupName}" ]] && [[ "${remoteGroupName}" != "-" ]]; then
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chgrp -R ${remoteGroupName} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chgrp ${remoteGroupName} ${remotePath}"
      fi
    fi

    if [[ -n "${remoteAccessRights}" ]] && [[ "${remoteAccessRights}" != "-" ]]; then
      if [[ -d "${localPath}" ]]; then
        docker exec "${containerName}" bash -c "chmod -R ${remoteAccessRights} ${remotePath}"
      else
        docker exec "${containerName}" bash -c "chmod ${remoteAccessRights} ${remotePath}"
      fi
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCopyQuiet
