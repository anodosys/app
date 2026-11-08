#!/bin/bash -e

if [[ -n "${anodosysPath}" ]]; then
  anodosysLibPath="${anodosysPath}/lib"
  export anodosysLibPath

  anodosysConfigurationPath="${anodosysPath}/configuration"
  export anodosysConfigurationPath

  anodosysConstructPath="${anodosysPath}/construct"
  export anodosysConstructPath

  anodosysActionPath="${anodosysPath}/action"
  anodosysActionSystemPath="${anodosysActionPath}/system"
  export anodosysActionSystemPath
  anodosysActionServerPath="${anodosysActionPath}/server"
  export anodosysActionServerPath

  anodosysExtensionPath="${anodosysPath}/extension"
  # installed releases share their extensions so they survive updates
  if [[ -L "$(dirname "${anodosysPath}")/current" ]]; then
    anodosysExtensionPath="$(dirname "${anodosysPath}")/extension"
  fi
  export anodosysExtensionPath

  currentUser=$(whoami)
  currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

  # ANODOSYS_USER_PATH replaces ~/.anodosys, for example to run the smoke tests isolated from the real user setup
  anodosysUserPath="${ANODOSYS_USER_PATH:-${currentUserHome}/.anodosys}"
  mkdir -p "${anodosysUserPath}"
  export anodosysUserPath

  anodosysUserLibPath="${anodosysUserPath}/lib"
  mkdir -p "${anodosysUserLibPath}"
  export anodosysUserLibPath

  anodosysUserConfigurationPath="${anodosysUserPath}/configuration"
  mkdir -p "${anodosysUserConfigurationPath}"
  export anodosysUserConfigurationPath

  anodosysUserConstructPath="${anodosysUserPath}/construct"
  mkdir -p "${anodosysUserConstructPath}"
  export anodosysUserConstructPath

  anodosysUserExtensionPath="${anodosysUserPath}/extension"
  mkdir -p "${anodosysUserExtensionPath}"
  export anodosysUserExtensionPath

  anodosysUserHostPath="${anodosysUserPath}/host"
  mkdir -p "${anodosysUserHostPath}"
  export anodosysUserHostPath

  anodosysUserActionPath="${anodosysUserPath}/action"
  mkdir -p "${anodosysUserActionPath}"
  anodosysUserActionSystemPath="${anodosysUserActionPath}/system"
  export anodosysUserActionSystemPath
  anodosysUserActionServerPath="${anodosysUserActionPath}/server"
  export anodosysUserActionServerPath

  anodosysUserVarPath="${anodosysUserPath}/var"
  mkdir -p "${anodosysUserVarPath}"
  export anodosysUserVarPath

  anodosysUserVarConfigurationPath="${anodosysUserVarPath}/configuration"
  mkdir -p "${anodosysUserVarConfigurationPath}"
  export anodosysUserVarConfigurationPath

  anodosysUserVarVolumePath="${anodosysUserVarPath}/volume"
  mkdir -p "${anodosysUserVarVolumePath}"
  export anodosysUserVarVolumePath

  anodosysUserVarEnvPath="${anodosysUserVarPath}/env"
  mkdir -p "${anodosysUserVarEnvPath}"
  export anodosysUserVarEnvPath

  anodosysUserVarLogPath="${anodosysUserVarPath}/log"
  mkdir -p "${anodosysUserVarLogPath}"
  export anodosysUserVarLogPath

  if [[ -d "${anodosysExtensionPath}" ]]; then
    anodosysExtensions=( $(find "${anodosysExtensionPath}" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n") )
  else
    anodosysExtensions=()
  fi
  export anodosysExtensions

  if [[ -d "${anodosysUserExtensionPath}" ]]; then
    anodosysUserExtensions=( $(find "${anodosysUserExtensionPath}" -mindepth 1 -maxdepth 1 -xtype d -printf "%f\n") )
  else
    anodosysUserExtensions=()
  fi
  export anodosysUserExtensions
fi
