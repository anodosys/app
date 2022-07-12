#!/bin/bash -e

if [[ -z "${anodosysConfigurationFile}" ]]; then
  >&2 echo "No anodosys configuration file defined"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name
  -o  Output variables, default: no

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

prepareConfigurationVariables()
{
  local serverName="${1}"
  local outputVars="${2:-no}"
  keys=( $(cat "${anodosysConfigurationFile}" | jq -r ".${serverName} | keys_unsorted[]") )
  for key in "${keys[@]}"; do
    oldIFS="${IFS}"
    IFS=$'\n'
    values=( $(cat "${anodosysConfigurationFile}" | jq -r ".${serverName} .${key} | if type==\"array\" then values[] else if type==\"null\" then \"\" else . end end") )
    IFS="${oldIFS}"
    if [[ "${#values[@]}" -gt 1 ]]; then
      if [ -z ${!key+x} ]; then
        eval "${key}=( )"
        if [[ "${outputVars}" == "yes" ]]; then
          echo "${key}=( )"
        fi
      fi
      for value in "${values[@]}"; do
        value=$(prepareValue "${value}")
        eval "${key}+=(\"${value}\")"
        if [[ "${outputVars}" == "yes" ]]; then
          eval "value=\"${value}\""
          echo "${key}+=(\"${value}\")"
        fi
      done
    elif [[ "${#values[@]}" -eq 1 ]]; then
      value=$(prepareValue "${values[0]}")
      if [ -z ${!key+x} ]; then
        eval "${key}=\"${value}\""
        if [[ "${outputVars}" == "yes" ]]; then
          eval "value=\"${value}\""
          echo "${key}=\"${value}\""
        fi
      fi
    fi
  done
}

serverName=
outputVars=0

while getopts hs:o? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    o) outputVars=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

if [[ "${outputVars}" == 1 ]]; then
  prepareConfigurationVariables "global" "yes"
  prepareConfigurationVariables "${serverName}" "yes"
else
  prepareConfigurationVariables "global"
  prepareConfigurationVariables "${serverName}"
fi
