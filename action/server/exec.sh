#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

shift

if [[ -z "${1}" ]]; then
  >&2 echo "No server name specified"
  exit 1
fi

serverName="${1}"
shift

if [[ -n "${1}" ]]; then
  script="${1}"
  shift
  if [[ ! -f "${script}" ]]; then
    >&2 echo "Script not found at: ${script}"
    exit 1
  fi
else
  >&2 echo "No script specified"
  exit 1
fi

if [[ -n "${prepareParametersListParts}" ]]; then
  prepareParameters=$(printf ",%s" "${prepareParametersListParts[@]}")
  prepareParameters="${prepareParameters:1}"

  "${anodosysAppPath}/server/container/execute.sh" \
    -s "${serverName}" \
    -c "${script}" \
    -p "${prepareParameters}"
else
  "${anodosysAppPath}/server/container/execute.sh" \
    -s "${serverName}" \
    -c "${script}"
fi
