#!/bin/bash -e

if [[ -z "${action}" ]]; then
  >&2 echo "No action defined"
  exit 1
fi

if [[ -z "${anodosysConfigurationFile}" ]]; then
  >&2 echo "No anodosys configuration file defined"
  exit 1
fi

if [[ "${action}" == "config" ]]; then
  if [[ -n "${2}" ]]; then
    propertyName="${2}"
    result=$(cat "${anodosysConfigurationFile}" | jq -r ".global .${propertyName} | if type==\"array\" then values[] else . end // empty") && [[ -n "$result" ]] && echo "${result}" || cat "${anodosysConfigurationFile}" | jq -r ".system .${propertyName} | if type==\"array\" then values[] else . end //empty"
  else
    cat "${anodosysConfigurationFile}"
  fi
  exit 0
fi
