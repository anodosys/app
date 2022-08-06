#!/bin/bash -e

containerCommand()
{
  local containerName="${1}"
  local command="${2}"
  local interactive="${3:-0}"
  local userName="${4}"
  local flags="-t"
  if [[ "${interactive}" == 1 ]]; then
    flags+="i"
  fi
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    if [[ -z "${userName}" ]] || [[ "${userName}" == "none" ]]; then
      echo "Executing command in container: ${containerName}: ${command}"
      docker exec "${flags}" "${containerName}" bash -c "${command}"
    else
      echo "Executing command with user: ${userName} in container: ${containerName}: ${command}"
      docker exec "${flags}" -u "${userName}" "${containerName}" bash -c "${command}"
    fi
  else
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCommand

containerCommandQuiet()
{
  local containerName="${1}"
  local command="${2}"
  local interactive="${3:-0}"
  local userName="${4}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    if [[ -z "${userName}" ]] || [[ "${userName}" == "none" ]]; then
      docker exec "${containerName}" bash -c "${command}"
    else
      docker exec -u "${userName}" "${containerName}" bash -c "${command}"
    fi
  else
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCommandQuiet
