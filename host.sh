#!/bin/bash -e

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi

anodosysPath=$(cd -P "$( dirname "${scriptName}" )" && pwd)

anodosysHostPath="${anodosysPath}/host"

anodosysExtensionPath="${anodosysPath}/extension"

currentUser=$(whoami)
currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

anodosysUserPath="${currentUserHome}/.anodosys"
mkdir -p "${anodosysUserPath}"

anodosysUserExtensionPath="${anodosysUserPath}/extension"
mkdir -p "${anodosysUserExtensionPath}"

if [[ -d "${anodosysExtensionPath}" ]]; then
  anodosysSharedExtensions=( $(find "${anodosysExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )
else
  anodosysSharedExtensions=()
fi

anodosysUserExtensions=( $(find "${anodosysUserExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )

(
  [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
  [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] ||
  [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) && sourced=1 || sourced=0

if [[ "${sourced}" == 1 ]]; then
  if [[ -d "${anodosysHostPath}" ]]; then
    echo "Adding to path: ${anodosysHostPath}"
    export PATH="${PATH}:${anodosysHostPath}"
  fi

  for anodosysExtension in "${anodosysSharedExtensions[@]}"; do
    if [[ -d "${anodosysExtensionPath}/${anodosysExtension}/host" ]]; then
      echo "Adding to path: ${anodosysExtensionPath}/${anodosysExtension}/host"
      export PATH="${PATH}:${anodosysExtensionPath}/${anodosysExtension}/host"
    fi
  done

  for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
    if [[ -d "${anodosysUserExtensionPath}/${anodosysUserExtension}/host" ]]; then
      echo "Adding to path: ${anodosysUserExtensionPath}/${anodosysUserExtension}/host"
      export PATH="${PATH}:${anodosysUserExtensionPath}/${anodosysUserExtension}/host"
    fi
  done
else
  2>&1 echo "To add host script path, source the script, i.e.:"
  2>&1 echo "source ${anodosysPath}/host.sh"
fi
