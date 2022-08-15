#!/bin/bash -e

prepareValue()
{
  local text="$*"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  text=$(printf '%s' "${text}")
  text="${text%\"}"
  text="${text#\"}"
  echo -n "${text}"
}

# shellcheck disable=SC2034
typeset -fx prepareValue

currentTimeStamp=$(date +%s)
export currentTimeStamp

duration()
{
  local timeStamp="${1}"
  local difference
  local days
  local hours
  local minutes
  local seconds

  if [[ -z "${timeStamp}" ]]; then
    exit 0
  fi

  difference=$((currentTimeStamp-timeStamp))
  days=$((difference/60/60/24))
  hours=$((difference/60/60%24))
  minutes=$((difference/60%60))
  seconds=$((difference%60))

  if [[ "${days}" -gt 0 ]]; then
    echo -n "${days}d"
  fi

  if [[ "${hours}" -gt 0 ]]; then
    if [[ "${days}" -gt 0 ]]; then
      echo -n " "
    fi
    echo -n "${hours}h"
  fi

  if [[ "${minutes}" -gt 0 ]]; then
    if [[ "${days}" -gt 0 ]] || [[ "${hours}" -gt 0 ]]; then
      echo -n " "
    fi
    echo -n "${minutes}m"
  fi

  if [[ "${days}" -eq 0 ]] && [[ "${hours}" -eq 0 ]]; then
    if [[ "${days}" -gt 0 ]] || [[ "${hours}" -gt 0 ]] || [[ "${minutes}" -gt 0 ]]; then
      echo -n " "
    fi
    echo -n "${seconds}s"
  fi

  echo ""
}

# shellcheck disable=SC2034
typeset -fx duration

if [[ -n "${anodosysLibPath}" ]] && [[ -d "${anodosysLibPath}" ]]; then
  libFiles=( $(find "${anodosysLibPath}" -type f -name "*.sh") )

  for libFile in "${libFiles[@]}"; do
    source "${libFile}"
  done
fi

if [[ -n "${anodosysUserLibPath}" ]] && [[ -d "${anodosysUserLibPath}" ]]; then
  libFiles=( $(find "${anodosysUserLibPath}" -type f -name "*.sh") )

  for libFile in "${libFiles[@]}"; do
    source "${libFile}"
  done
fi
