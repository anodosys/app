#!/bin/bash -e

anodosysPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

anodosysHostPath="${anodosysPath}/host"
mkdir -p "${anodosysHostPath}"

anodosysExtensionPath="${anodosysPath}/extension"
mkdir -p "${anodosysExtensionPath}"

anodosysExtensions=( $(find "${anodosysExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )

(
  [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
  [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] ||
  [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) && sourced=1 || sourced=0

if [[ "${sourced}" == 1 ]]; then
  echo "Adding to path: ${anodosysHostPath}"
  export PATH="${PATH}:${anodosysHostPath}"

  for anodosysExtension in "${anodosysExtensions[@]}"; do
    if [[ -d "${anodosysExtensionPath}/${anodosysExtension}/host" ]]; then
      echo "Adding to path: ${anodosysExtensionPath}/${anodosysExtension}/host"
      export PATH="${PATH}:${anodosysExtensionPath}/${anodosysExtension}/host"
    fi
  done
else
  2>&1 echo "To add host script path, source the script, i.e.:"
  2>&1 echo "source ${anodosysPath}/host.sh"
fi
