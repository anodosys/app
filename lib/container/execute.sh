#!/bin/bash -e

containerExecute()
{
  local containerName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")
  local remoteFileName

  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopy "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      echo "Executing script in container at: /${remoteFileName} ${parameters[*]}"
      docker exec "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    else
      >&2 echo "Container not running: ${containerName}"
      exit 1
    fi
  else
    >&2 echo "Could not find file at: ${localFileName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerExecute

containerExecuteUser()
{
  local containerName="${1}"
  shift
  local userName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")
  local remoteFileName

  if [[ -z "${userName}" ]]; then
    >&2 echo "No user name specified to execute script in container"
    exit 1
  fi

  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopy "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      echo "Executing script in container at: /${remoteFileName} ${parameters[*]}"
      docker exec --user "${userName}" "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    else
      >&2 echo "Container not running: ${containerName}"
      exit 1
    fi
  else
    >&2 echo "Could not find file at: ${localFileName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerExecuteUser

containerExecuteQuiet()
{
  local containerName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")
  local remoteFileName

  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopyQuiet "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      docker exec "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    else
      exit 1
    fi
  else
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerExecuteQuiet

containerExecuteUserQuiet()
{
  local containerName="${1}"
  shift
  local userName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")
  local remoteFileName

  if [[ -z "${userName}" ]]; then
    exit 1
  fi

  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopy "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      docker exec --user "${userName}" "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    else
      exit 1
    fi
  else
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerExecuteUserQuiet
