#!/bin/bash -e

if [[ -z "${anodosysConstructPath}" ]]; then
  >&2 echo "No anodosys construct path defined"
  exit 1
fi

if [[ -z "${anodosysUserConstructPath}" ]]; then
  >&2 echo "No anodosys user construct path defined"
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

if [[ -z "${action}" ]]; then
  >&2 echo "No action defined"
  exit 1
fi

if [[ "${action}" == "construct" ]]; then
  type="${2}"
  if [[ -n "${type}" ]]; then
    constructTypeScript="${anodosysConstructPath}/${type}.sh"
    if [[ -f "${constructTypeScript}" ]]; then
      source "${constructTypeScript}"
      exit 0
    else
      userConstructTypeScript="${anodosysUserConstructPath}/${type}.sh"
      if [[ -f "${userConstructTypeScript}" ]]; then
        source "${userConstructTypeScript}"
        exit 0
      else
        if [[ -n "${anodosysSharedExtensions}" ]]; then
          for anodosysExtension in "${anodosysSharedExtensions[@]}"; do
            if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/construct/${type}.sh" ]]; then
              source "${anodosysExtensionPath}/${anodosysExtension}/construct/${type}.sh"
              exit 0
            fi
          done
        fi
        if [[ -n "${anodosysUserExtensions}" ]]; then
          for anodosysExtension in "${anodosysUserExtensions[@]}"; do
            if [[ -f "${anodosysUserExtensionPath}/${anodosysExtension}/construct/${type}.sh" ]]; then
              source "${anodosysUserExtensionPath}/${anodosysExtension}/construct/${type}.sh"
              exit 0
            fi
          done
        fi
        >&2 echo "No handling of type: ${type} defined"
        exit 1
      fi
    fi
  fi
  exit 0
fi
