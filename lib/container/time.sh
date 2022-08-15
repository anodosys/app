#!/bin/bash -e

containerCreateTime()
{
  local containerName="${1}"
  local format="${2:-"%Y-%m-%d %H:%M:%S"}"

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    date --date="$(docker inspect -f "{{ .Created }}" "${containerName}")" "+${format}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerCreateTime

containerStartTime()
{
  local containerName="${1}"
  local format="${2:-"%Y-%m-%d %H:%M:%S"}"

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    date --date="$(docker inspect -f "{{ .State.StartedAt }}" "${containerName}")" "+${format}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerStartTime
