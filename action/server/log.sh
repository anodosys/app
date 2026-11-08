#!/bin/bash -e

if [[ -z "${anodosysUserVarLogPath}" ]]; then
  >&2 echo "No anodosys log path defined"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined"
  exit 1
fi

logFilePath="${anodosysUserVarLogPath}/${systemName}.log"

if [[ ! -f "${logFilePath}" ]]; then
  >&2 echo "No log file found for system: ${systemName} at: ${logFilePath}"
  exit 1
fi

if [[ -z "${lines}" ]]; then
  lines=100
fi

if [[ ! "${lines}" =~ ^[0-9]+$ ]]; then
  >&2 echo "Invalid number of lines: ${lines}"
  exit 1
fi

echo "Log file: ${logFilePath}" | sed $'s,.*,\e[1;37m&\e[m,'

# set by the --follow parameter
# shellcheck disable=SC2154
if [[ "${follow}" == 1 ]]; then
  tail -n "${lines}" -F "${logFilePath}"
else
  tail -n "${lines}" "${logFilePath}"
fi
