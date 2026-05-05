#!/bin/bash -e

if [[ -z "${anodosysConfigurationFile}" ]]; then
  >&2 echo "No anodosys configuration file defined"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No anodosys user var configuration path defined"
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
  local keys
  local key
  local values
  local value
  local placeholderKey
  local placeholderKeys=()

  # shellcheck disable=SC2002
  keys=( $(cat "${anodosysConfigurationFile}" | jq -r ".${serverName} //empty | keys_unsorted[]") )
  for key in "${keys[@]}"; do
    oldIFS="${IFS}"
    IFS=$'\n'
    # shellcheck disable=SC2002
    values=( $(cat "${anodosysConfigurationFile}" | jq -r ".${serverName} .${key} | if type==\"array\" then values[] else if type==\"null\" then \"\" else . end end") )
    IFS="${oldIFS}"
    if [[ "${#values[@]}" -gt 1 ]]; then
      placeholderKey=0
      for value in "${values[@]}"; do
        if [[ "${value}" =~ \<.*?\> ]]; then
          placeholderKey=1
        fi
      done
      if [[ "${placeholderKey}" == 1 ]]; then
        placeholderKeys+=("${key}")
        continue
      fi
      if [ -z ${!key+x} ]; then
        eval "${key}=( )"
        if [[ "${outputVars}" == "yes" ]]; then
          echo "${key}=( )"
        fi
      fi
      for value in "${values[@]}"; do
        value=$(echo "${value}" | sed 's/<\([[:alnum:]]\+\)>/${\1}/g')
        value=$(prepareValue "${value}")
        eval "${key}+=(\"${value}\")"
        if [[ "${outputVars}" == "yes" ]]; then
          eval "value=\"${value}\""
          echo "${key}+=(\"${value}\")"
          #>&2 echo "1: ${key}+=(\"${value}\")"
        fi
      done
    elif [[ "${#values[@]}" -eq 1 ]]; then
      value="${values[0]}"
      if [[ "${value}" =~ \<.*?\> ]]; then
        placeholderKeys+=("${key}")
      else
        if [ -z ${!key+x} ]; then
          value=$(echo "${value}" | sed 's/<\([[:alnum:]]\+\)>/${\1}/g')
          value=$(prepareValue "${value}")
          eval "${key}=\"${value}\""
          if [[ "${outputVars}" == "yes" ]]; then
            eval "value=\"${value}\""
            echo "${key}=\"${value}\""
            #>&2 echo "2: ${key}=\"${value}\""
          fi
        fi
      fi
    fi
  done

  for key in "${placeholderKeys[@]}"; do
    oldIFS="${IFS}"
    IFS=$'\n'
    # shellcheck disable=SC2002
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
        valueKeys=( $(echo "${value}" | grep -oP '<([[:alnum:]]+)>' | sed 's/^<//g' | sed 's/>$//g') )
        for valueKey in "${valueKeys[@]}"; do
          valueType=$(declare -p "${valueKey}" 2>/dev/null)
          if [[ "${valueType}" =~ "declare -a" ]]; then
            value="${value/<${valueKey}>/"\${${valueKey}Concatenated}"}"
            eval "declare -n valueList=${valueKey}"
            # shellcheck disable=SC2154
            valueConcatenated=$(IFS=,; echo "${valueList[*]}")
            eval "${valueKey}Concatenated=\"${valueConcatenated}\""
          fi
        done
        value=$(echo "${value}" | sed 's/<\([[:alnum:]]\+\)>/${\1}/g')
        value=$(prepareValue "${value}")
        eval "${key}+=(\"${value}\")"
        if [[ "${outputVars}" == "yes" ]]; then
          eval "value=\"${value}\""
          echo "${key}+=(\"${value}\")"
          #>&2 echo "3: ${key}+=(\"${value}\")"
        fi
      done
    elif [[ "${#values[@]}" -eq 1 ]]; then
      if [ -z ${!key+x} ]; then
        value="${values[0]}"
        value=$(echo "${value}" | sed 's/<\([[:alnum:]]\+\)>/${\1}/g')
        value=$(prepareValue "${value}")
        eval "${key}=\"${value}\""
        if [[ "${outputVars}" == "yes" ]]; then
          eval "value=\"${value}\""
          echo "${key}=\"${value}\""
          #>&2 echo "4: ${key}=\"${value}\""
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
  if [[ "${serverName}" != "system" ]]; then
    prepareConfigurationVariables "any" "yes"
  fi
  prepareConfigurationVariables "${serverName}" "yes"
else
  prepareConfigurationVariables "global"
  if [[ "${serverName}" != "system" ]]; then
    prepareConfigurationVariables "any"
  fi
  prepareConfigurationVariables "${serverName}"
fi
