#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

anodosysSystemPath="${anodosysAppPath}/system"

declare -A stepScripts

if [[ -d "${anodosysSystemPath}" ]]; then
  stepScriptFiles=( $(find "${anodosysSystemPath}" -type f -name "*.sh") )

  for stepScriptFile in "${stepScriptFiles[@]}"; do
    stepName=$(echo -n "${stepScriptFile:$((${#anodosysSystemPath}+1)):-3}" | tr -c -s '[:alnum:][:blank:]' '_' | sed -r 's/(.)_+(.)/\1\U\2/g;s/^[a-z]/\U&/' | sed -r 's/^./\L&/')

    stepScripts["${stepName}"]="${stepScriptFile}"
  done
fi

export stepScripts
