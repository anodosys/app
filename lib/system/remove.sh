#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemRemove()
{
  local systemName="${1}"
  local systemsFile="${anodosysUserPath}/systems.json"

  (
    # several systems run at the same time, so the file is locked while it is changed
    flock 9

    if [[ ! -s "${systemsFile}" ]]; then
      echo "{}" > "${systemsFile}"
    fi

    if [[ $(jq -r --arg name "${systemName}" 'has($name)' "${systemsFile}") == "true" ]]; then
      echo "Removing system with name: ${systemName}"
      jq --arg name "${systemName}" 'del(.[$name])' "${systemsFile}" > "${systemsFile}.tmp"
      mv "${systemsFile}.tmp" "${systemsFile}"
    else
      echo "No need to remove system with name: ${systemName}"
    fi
  ) 9>"${systemsFile}.lock"
}

# shellcheck disable=SC2034
typeset -fx systemRemove
