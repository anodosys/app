#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

# The state of a system is read from Docker, not stored: a container belongs to a system by its label anodosys.system.
# Containers created before that label existed are recognized by com.docker.compose.project if the project is a
# registered system and com.docker.compose.version is missing (docker compose, and with it ddev, always sets it).

declare -A listConfigurationFiles=()
declare -A listContainers=()
declare -A listRunning=()

if [[ -f "${anodosysUserPath}/systems.json" ]]; then
  while IFS=$'\t' read -r listSystemName listConfigurationFile; do
    [[ -n "${listSystemName}" ]] && listConfigurationFiles["${listSystemName}"]="${listConfigurationFile}"
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "${anodosysUserPath}/systems.json")
fi

if ! listDockerContainers=$(docker ps -a --format '{{.Label "anodosys.system"}}|{{.Label "com.docker.compose.project"}}|{{.Label "com.docker.compose.version"}}|{{.State}}' 2>&1); then
  >&2 echo "Could not read containers from Docker: ${listDockerContainers}"
  exit 1
fi

# | instead of a tab: read merges consecutive whitespace separators, so empty labels would shift the fields
while IFS='|' read -r listLabelSystem listLabelProject listLabelComposeVersion listState; do
  if [[ -n "${listLabelSystem}" ]]; then
    listSystemName="${listLabelSystem}"
  elif [[ -n "${listLabelProject}" ]] && [[ -z "${listLabelComposeVersion}" ]] && [[ -n "${listConfigurationFiles[${listLabelProject}]+x}" ]]; then
    listSystemName="${listLabelProject}"
  else
    continue
  fi
  listContainers["${listSystemName}"]=$(( ${listContainers[${listSystemName}]:-0} + 1 ))
  if [[ "${listState}" == "running" ]]; then
    listRunning["${listSystemName}"]=$(( ${listRunning[${listSystemName}]:-0} + 1 ))
  fi
done <<< "${listDockerContainers}"

mapfile -t listSystemNames < <(printf '%s\n' "${!listConfigurationFiles[@]}" "${!listContainers[@]}" | sed '/^$/d' | sort -u)

if [[ "${#listSystemNames[@]}" -eq 0 ]]; then
  echo "No systems available"
  exit 0
fi

listStarted=()
listPartly=()
listStopped=()
listNotCreated=()
for listSystemName in "${listSystemNames[@]}"; do
  listTotal="${listContainers[${listSystemName}]:-0}"
  listRunningCount="${listRunning[${listSystemName}]:-0}"
  listEntry="${listSystemName}"
  if [[ -n "${listConfigurationFiles[${listSystemName}]+x}" ]]; then
    if [[ ! -f "${listConfigurationFiles[${listSystemName}]}" ]]; then
      listEntry+=" (configuration missing: ${listConfigurationFiles[${listSystemName}]})"
    fi
  else
    listEntry+=" (not registered)"
  fi
  if [[ "${listTotal}" -eq 0 ]]; then
    listNotCreated+=("${listEntry}")
  elif [[ "${listRunningCount}" -eq "${listTotal}" ]]; then
    listStarted+=("${listEntry}")
  elif [[ "${listRunningCount}" -eq 0 ]]; then
    listStopped+=("${listEntry}")
  else
    listPartly+=("${listEntry} (${listRunningCount}/${listTotal} running)")
  fi
done

listSection()
{
  local title="${1}"
  shift
  local entry

  if [[ "$#" -gt 0 ]]; then
    echo ""
    echo "${title}" | sed $'s,.*,\e[1;37m&\e[m,'
    for entry in "$@"; do
      echo "${entry}"
    done
  fi
}

listSection "Started" "${listStarted[@]}"
listSection "Partly started" "${listPartly[@]}"
listSection "Stopped" "${listStopped[@]}"
listSection "Not created" "${listNotCreated[@]}"
echo ""
