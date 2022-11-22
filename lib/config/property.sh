#!/bin/bash -e

addProperty()
{
  local name="${1}"
  local value="${2}"
  local overwrite="${3:-0}"
  local append="${4:-0}"
  local raw="${5:-0}"
  local fileName

  if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]]; then
    echo "{}" > ads.json
  fi

  if [[ -f "anodosys.json" ]]; then
    fileName="anodosys.json"
  else
    fileName="ads.json"
  fi

  addFileProperty "${fileName}" "${name}" "${value}" "${overwrite}" "${append}" "${raw}"
}

# shellcheck disable=SC2034
typeset -fx addProperty

addFileProperty()
{
  local fileName="${1}"
  local name="${2}"
  local value="${3}"
  local overwrite="${4:-0}"
  local append="${5:-0}"
  local raw="${6:-0}"

  oldIFS="${IFS}"
  IFS=$'\n'
  currentValues=( $(jq ".${name} | if type==\"array\" or type==\"object\" then values[] else . end //empty" "${fileName}") )
  IFS="${oldIFS}"

  add=1
  if [[ "${#currentValues[@]}" -gt 0 ]]; then
    if [[ "${overwrite}" == 0 ]] && [[ "${append}" == 0 ]]; then
      >&2 echo "Property already exists!"
      exit 1
    fi
    if [[ "${append}" == 1 ]]; then
      for currentValue in "${currentValues[@]}"; do
        if [[ "${currentValue}" == "${value}" ]] || [[ "${currentValue}" == "\"${value}\"" ]]; then
          if [[ "${overwrite}" == 0 ]]; then
            >&2 echo "Property already exists!"
            exit 1
          else
            add=0
          fi
        elif [[ "${raw}" == 1 ]]; then
          if [[ "${currentValue}" == "\"${value}\"" ]]; then
            if [[ "${overwrite}" == 0 ]]; then
              >&2 echo "Property already exists!"
              exit 1
            else
              add=0
            fi
          fi
        fi
      done
      if [[ "${#currentValues[@]}" -eq 1 ]]; then
        tmpFile=$(mktemp)
        jq ".${name} = [${currentValues[0]}]" "${fileName}" > "${tmpFile}" && mv "${tmpFile}" "${fileName}"
      fi
    fi
  fi

  if [[ "${add}" == 1 ]]; then
    tmpFile=$(mktemp)
    if [[ "${append}" == 0 ]]; then
      if [[ "${raw}" == 0 ]] && [[ "${value}" =~ ^[0-9]+$ ]]; then
        jq ".${name} = ${value}" "${fileName}" > "${tmpFile}" && mv "${tmpFile}" "${fileName}"
      else
        jq ".${name} = \"${value}\"" "${fileName}" > "${tmpFile}" && mv "${tmpFile}" "${fileName}"
      fi
    else
      if [[ "${raw}" == 0 ]] && [[ "${value}" =~ ^[0-9]+$ ]]; then
        jq ".${name} += [${value}]" "${fileName}" > "${tmpFile}" && mv "${tmpFile}" "${fileName}"
      else
        jq ".${name} += [\"${value}\"]" "${fileName}" > "${tmpFile}" && mv "${tmpFile}" "${fileName}"
      fi
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx addFileProperty

addServerProperty()
{
  local serverName="${1}"
  local name="${2}"
  local value="${3}"
  local overwrite="${4:-0}"
  local append="${5:-0}"
  local raw="${6:-0}"
  local fileName

  if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]]; then
    echo "{}" > ads.json
  fi

  if [[ -f "anodosys.json" ]]; then
    fileName="anodosys.json"
  else
    fileName="ads.json"
  fi

  addFileProperty "${fileName}" "${serverName}.${name}" "${value}" "${overwrite}" "${append}" "${raw}"
}

# shellcheck disable=SC2034
typeset -fx addServerProperty

addFileServerProperty()
{
  local fileName="${1}"
  local serverName="${2}"
  local name="${3}"
  local value="${4}"
  local overwrite="${5:-0}"
  local append="${6:-0}"
  local raw="${7:-0}"

  addFileProperty "${fileName}" "${serverName}.${name}" "${value}" "${overwrite}" "${append}" "${raw}"
}

# shellcheck disable=SC2034
typeset -fx addFileServerProperty
