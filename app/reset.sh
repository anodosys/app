#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path defined"
  exit 1
fi

if [[ -z "${action}" ]]; then
  >&2 echo "No action defined"
  exit 1
fi

if [[ "${action}" == "reset" ]]; then
  type="${2:-all}"
  if [[ "${type}" == "all" ]] && [[ -d "${anodosysUserVarPath}" ]]; then
    echo "Removing all files in path: ${anodosysUserVarPath:?}"
    rm -rf "${anodosysUserVarPath:?}/*"
    mkdir -p "${anodosysUserVarPath:?}/configuration"
    mkdir -p "${anodosysUserVarPath:?}/extension"
  fi
  if [[ -d "${anodosysUserVarPath}/${type}" ]]; then
    echo "Removing all files in path: ${anodosysUserVarPath:?}/${type}"
    rm -rf "${anodosysUserVarPath:?}/${type}/*"
  fi
  exit 0
fi
