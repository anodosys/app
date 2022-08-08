#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemStop()
{
  local systemName="${1}"

  if [[ ! -f "${anodosysUserPath}/status.json" ]]; then
    echo "{}" > "${anodosysUserPath}/status.json"
  fi

  echo "Updating system status with name: ${systemName} to: stopped"
  $(cd "${anodosysUserPath}"; jq -j ". += {\"${systemName}\":false}" status.json | ex -sc 'wq!status.json' /dev/stdin)
}

# shellcheck disable=SC2034
typeset -fx systemStop
