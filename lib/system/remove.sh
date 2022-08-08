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

  echo "Removing system with name: ${systemName}"
  $(cd "${anodosysUserPath}"; jq "del(.${systemName})" systems.json | ex -sc 'wq!systems.json' /dev/stdin)
}

# shellcheck disable=SC2034
typeset -fx systemRemove
