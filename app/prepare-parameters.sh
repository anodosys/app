#!/bin/bash -e

declare -Ag parameters
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter:0:2}" == "--" ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      parameter="${parameter:2}"
      key=$(echo "${parameter}" | grep -oP '[[:alpha:]]+(?=\s)' | tr -d "\n")
      value=$(echo "${parameter:${#key}}" | xargs)
      # shellcheck disable=SC2034
      parameters["${key}"]="${value}"
      eval "${key}=\"${value}\""
      continue
    fi
    if [[ "${parameter:0:2}" == "--" ]]; then
      key="${parameter:2}"
    elif [[ "${parameter}" =~ ^-\?$ ]]; then
      key="help"
    else
      key="${parameter:1}"
    fi
    if [[ "$#" -eq 0 ]]; then
      parameters["${key}"]=1
      eval "${key}=1"
    else
      value="${1}"
      if [[ "${value:0:2}" == "--" ]]; then
        parameters["${key}"]=1
        eval "${key}=1"
        continue
      fi
      shift
      # shellcheck disable=SC2034
      parameters["${key}"]="${value}"
      eval "${key}=\"${value}\""
    fi
  else
    unparsedParameters+=("${parameter}")
  fi
done
set -- "${unparsedParameters[@]}"

if test "${parameters["help"]+isset}" || test "${parameters["?"]+isset}"; then
  if [[ $(declare -F "usage" | wc -l) -gt 0 ]]; then
    usage
    exit 0
  fi
fi
