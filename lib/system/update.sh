#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

systemUpdate()
{
  local systems
  local configurationFiles
  local configurationFile
  local systemName

  declare -A systems
  configurationFiles=( $(cat "${anodosysUserPath}/systems.json" | jq -r '.[] //empty' | sort -u) )
  for configurationFile in "${configurationFiles[@]}"; do
    if [[ -f "${configurationFile}" ]]; then
      ads config --fileName "${configurationFile}" >/dev/null
      systemName=$(ads config systemName --fileName "${configurationFile}")
      systems["${systemName}"]="${configurationFile}"
    fi
  done

  systemNames=( $(echo "${!systems[@]}" | tr " " "\n" | sort -u) )

  echo "{}" > "${anodosysUserPath}/systems.json"
  for systemName in "${systemNames[@]}"; do
    $(cd "${anodosysUserPath}"; jq -j ". += {\"${systemName}\":\"${systems[${systemName}]}\"}" systems.json | ex -sc 'wq!systems.json' /dev/stdin)
  done
}

# shellcheck disable=SC2034
typeset -fx systemUpdate
