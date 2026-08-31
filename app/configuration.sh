#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No app path specified!"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No user var configuration path specified!"
  exit 1
fi

if [[ -z "${anodosysExtensionPath}" ]]; then
  >&2 echo "No extension path specified!"
  exit 1
fi

if [[ -z "${anodosysUserExtensionPath}" ]]; then
  >&2 echo "No user extension path specified!"
  exit 1
fi

if [[ -z "${fileName}" ]]; then
  >&2 echo "No file name specified!"
  exit 1
fi

if [[ -z "${reset}" ]]; then
  >&2 echo "No reset specified!"
  exit 1
fi

# shellcheck disable=SC2154
if [[ "${#stepScripts[@]}" -eq 0 ]]; then
  >&2 echo "No step scripts defined"
  exit 1
fi

createServerConfiguration()
{
  local configurationHash="${1}"
  local systemName="${2}"
  local serverName="${3}"
  local reset="${4:-0}"
  local configurationHashServerFile
  local systemServerFile

  configurationHashServerFile="${anodosysUserVarConfigurationPath}/${configurationHash}_${serverName}.ini"
  systemServerFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"

  if [[ ! -f "${configurationHashServerFile}" ]] || [[ "${reset}" == 1 ]]; then
    if [[ "${serverName}" == "system" ]]; then
      j2v convert --file "${anodosysConfigurationFile}" --key global --key "${serverName}" --output "${configurationHashServerFile}"
    else
      j2v convert --file "${anodosysConfigurationFile}" --key global --key any --key "${serverName}" --output "${configurationHashServerFile}"
    fi
    cp "${configurationHashServerFile}" "${systemServerFile}"
  fi
}

setServerConfiguration()
{
  local systemName="${1}"
  local serverName="${2}"
  local configurationFile

  configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"

  if [[ -f "${configurationFile}" ]]; then
    source "${configurationFile}"
  fi
}

# shellcheck disable=SC2034
typeset -fx setServerConfiguration

configurationFileName=$(realpath "${fileName}")
export configurationFileName

params=( "--file" "${configurationFileName}" )

if [[ -n "${anodosysExtensions}" ]]; then
  for anodosysExtension in "${anodosysExtensions[@]}"; do
    params+=( "--param" "${anodosysExtension}:${anodosysExtensionPath}/${anodosysExtension}" )
  done
fi

if [[ -n "${anodosysUserExtensions}" ]]; then
  for anodosysExtension in "${anodosysUserExtensions[@]}"; do
    params+=( "--param" "${anodosysExtension}:${anodosysUserExtensionPath}/${anodosysExtension}" )
  done
fi

params+=( "--level" "1:input" )
params+=( "--level" "2:object:global" )
params+=( "--level" "3:suffix:/configuration" )
params+=( "--level" "4:suffix:/script" )
params+=( "--sort" )

set +e
configuration=$(jcp process "${params[@]}")
lastExitCode=$?
set -e

if [[ "${lastExitCode}" != 0 ]]; then
  >&2 echo "${configuration}"
  echo ""
  exit 1
fi

configurationHash=$(echo "${configuration}" | md5sum | awk '{print $1}')
anodosysConfigurationFile="${anodosysUserVarConfigurationPath}/${configurationHash}.json"
export anodosysConfigurationFile

echo "${configuration}" > "${anodosysConfigurationFile}"

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi

createServerConfiguration "${configurationHash}" "${systemName}" "system" "${reset}"

setServerConfiguration "${systemName}" "system"

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

for serverName in "${serverNames[@]}"; do
  createServerConfiguration "${configurationHash}" "${systemName}" "${serverName}" "${reset}"
done
