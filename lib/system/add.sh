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

  if [[ $(jq -r ". | has(\"${systemName}\")" "${anodosysUserPath}/systems.json") == "false" ]]; then
    echo "Adding system with name: ${systemName} and configuration file: ${configurationFile}"
    (cd "${anodosysUserPath}"; jq ". += {\"${systemName}\":\"${configurationFile}\"}" systems.json > systems.json.tmp && mv systems.json.tmp systems.json)
  else
    echo "No need to add system with name: ${systemName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx systemAdd
