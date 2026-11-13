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
    (cd "${anodosysUserPath}"; jq "del(.\"${systemName}\")" systems.json > systems.json.tmp && mv systems.json.tmp systems.json)
  else
    echo "No need to remove system with name: ${systemName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx systemRemove
