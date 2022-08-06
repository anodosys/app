#!/bin/bash -e

containerCopy()
{
  local containerName="${1}"
  local localFileName="${2}"
  local remoteFileName="${3}"
  if [[ -z "${remoteFileName}" ]]; then
    remoteFileName=$(basename "${localFileName}")
  fi
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Copying file from: ${localFileName} to container: ${containerName} at: ${remoteFileName}"
    docker cp "${localFileName}" "${containerName}:${remoteFileName}"
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
  local localFileName="${2}"
  local remoteFileName="${3}"
  if [[ -z "${remoteFileName}" ]]; then
    remoteFileName=$(basename "${localFileName}")
  fi
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    docker cp "${localFileName}" "${containerName}:${remoteFileName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCopyQuiet
