#!/bin/bash -e

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

if [[ -f "${anodosysUserPath}/systems.json" ]]; then
  systemNames=( $(jq -r "keys[]" "${anodosysUserPath}/systems.json") )
  startedSystemNames=()
  stoppedSystemNames=()
  for systemName in "${systemNames[@]}"; do
    if [[ -f "${anodosysUserPath}/status.json" ]]; then
      running=$(jq -r ".${systemName} // empty" "${anodosysUserPath}/status.json")
    else
      running="false"
    fi
    if [[ "${running}" == "true" ]]; then
      startedSystemNames+=("${systemName}")
    else
      stoppedSystemNames+=("${systemName}")
    fi
  done
  if [[ "${#startedSystemNames[@]}" -gt 0 ]]; then
    echo ""
    echo "Started" | sed $'s,.*,\e[1;37m&\e[m,'
    for startedSystemName in "${startedSystemNames[@]}"; do
      echo "${startedSystemName}"
    done
  fi
  if [[ "${#stoppedSystemNames[@]}" -gt 0 ]]; then
    echo ""
    echo "Stopped" | sed $'s,.*,\e[1;37m&\e[m,'
    for stoppedSystemName in "${stoppedSystemNames[@]}"; do
      echo "${stoppedSystemName}"
    done
    echo ""
  fi
else
  echo "No systems available"
fi
