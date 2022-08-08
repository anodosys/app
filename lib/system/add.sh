#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemAdd()
{
  local systemName="${1}"
  local configurationFile="${2}"

  if [[ ! -f "${anodosysUserPath}/systems.json" ]]; then
    echo "{}" > "${anodosysUserPath}/systems.json"
  fi

  echo "Adding system with name: ${systemName} and configuration file: ${configurationFile}"
  $(cd "${anodosysUserPath}"; jq -j ". += {\"${systemName}\":\"${configurationFile}\"}" systems.json | ex -sc 'wq!systems.json' /dev/stdin)
}

# shellcheck disable=SC2034
typeset -fx systemAdd
