#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemAdd()
{
  local systemName="${1}"
  local configurationFile="${2}"
  local systemsFile="${anodosysUserPath}/systems.json"

  (
    # several systems run at the same time, so the file is locked while it is changed
    flock 9

    if [[ ! -s "${systemsFile}" ]]; then
      echo "{}" > "${systemsFile}"
    fi

    if [[ $(jq -r --arg name "${systemName}" 'has($name)' "${systemsFile}") == "false" ]]; then
      echo "Adding system with name: ${systemName} and configuration file: ${configurationFile}"
      jq --arg name "${systemName}" --arg file "${configurationFile}" '. + {($name): $file}' "${systemsFile}" > "${systemsFile}.tmp"
      mv "${systemsFile}.tmp" "${systemsFile}"
    else
      echo "No need to add system with name: ${systemName}"
    fi
  ) 9>"${systemsFile}.lock"
}

# shellcheck disable=SC2034
typeset -fx systemAdd
