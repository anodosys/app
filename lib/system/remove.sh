#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemRemove()
{
  local systemName="${1}"

  if [[ ! -f "${anodosysUserPath}/systems.json" ]]; then
    echo "{}" > "${anodosysUserPath}/systems.json"
  fi

  if [[ $(jq -r ". | has(\"${systemName}\")" "${anodosysUserPath}/systems.json") == "true" ]]; then
    echo "Removing system with name: ${systemName}"
    $(cd "${anodosysUserPath}"; jq "del(.\"${systemName}\")" systems.json | ex -sc 'wq!systems.json' /dev/stdin)
  else
    echo "No need to remove system with name: ${systemName}"
  fi

  if [[ $(jq -r ". | has(\"${systemName}\")" "${anodosysUserPath}/status.json") == "true" ]]; then
    echo "Removing system status with name: ${systemName}"
    $(cd "${anodosysUserPath}"; jq "del(.\"${systemName}\")" status.json | ex -sc 'wq!status.json' /dev/stdin)
  else
    echo "No need to remove system status with name: ${systemName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx systemRemove
