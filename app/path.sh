#!/bin/bash -e

if [[ -n "${anodosysPath}" ]]; then
  anodosysLibPath="${anodosysPath}/lib"
  export anodosysLibPath

  anodosysConfigurationPath="${anodosysPath}/configuration"
  export anodosysConfigurationPath

  anodosysScriptPath="${anodosysPath}/script"
  export anodosysScriptPath

  anodosysExtensionPath="${anodosysPath}/extension"
  export anodosysExtensionPath

  currentUser=$(whoami)
  currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

  anodosysUserPath="${currentUserHome}/.anodosys"
  mkdir -p "${anodosysUserPath}"
  export anodosysUserPath

  anodosysUserLibPath="${anodosysUserPath}/lib"
  mkdir -p "${anodosysUserLibPath}"
  export anodosysUserLibPath

  anodosysUserConfigurationPath="${anodosysUserPath}/configuration"
  mkdir -p "${anodosysUserConfigurationPath}"
  export anodosysUserConfigurationPath

  anodosysUserExtensionPath="${anodosysUserPath}/extension"
  mkdir -p "${anodosysUserExtensionPath}"
  export anodosysUserExtensionPath

  anodosysUserHostPath="${anodosysUserPath}/host"
  mkdir -p "${anodosysUserHostPath}"
  export anodosysUserHostPath

  anodosysUserScriptPath="${anodosysUserPath}/script"
  mkdir -p "${anodosysUserScriptPath}"
  export anodosysUserScriptPath

  anodosysUserVarPath="${anodosysUserPath}/var"
  mkdir -p "${anodosysUserVarPath}"
  export anodosysUserVarPath

  anodosysUserVarConfigurationPath="${anodosysUserVarPath}/configuration"
  mkdir -p "${anodosysUserVarConfigurationPath}"
  export anodosysUserVarConfigurationPath

  anodosysSharedExtensions=( $(find "${anodosysExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )
  export anodosysSharedExtensions
  anodosysUserExtensions=( $(find "${anodosysUserExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )
  export anodosysUserExtensions
fi
