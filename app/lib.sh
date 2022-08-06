#!/bin/bash -e

prepareValue()
{
  local text="$*"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  text=$(printf '%s' "${text}")
  text="${text%\"}"
  text="${text#\"}"
  echo -n "${text}"
}

# shellcheck disable=SC2034
typeset -fx prepareValue

if [[ -n "${anodosysLibPath}" ]] && [[ -d "${anodosysLibPath}" ]]; then
  libFiles=( $(find "${anodosysLibPath}" -type f -name "*.sh") )

  for libFile in "${libFiles[@]}"; do
    source "${libFile}"
  done
fi

if [[ -n "${anodosysUserLibPath}" ]] && [[ -d "${anodosysUserLibPath}" ]]; then
  libFiles=( $(find "${anodosysUserLibPath}" -type f -name "*.sh") )

  for libFile in "${libFiles[@]}"; do
    source "${libFile}"
  done
fi
