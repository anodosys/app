#!/bin/bash -e

(
  [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
  [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] ||
  [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) && sourced=1 || sourced=0

if [[ "${sourced}" == 1 ]]; then
  systemName="${1}"

  if [[ -n "${systemName}" ]]; then
    currentUser=$(whoami)
    currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

    anodosysUserPath="${currentUserHome}/.anodosys"
    mkdir -p "${anodosysUserPath}"

    if [[ -f "${anodosysUserPath}/systems.json" ]]; then
      configurationFile=$(jq -r ". | with_entries(select(.key|match(\"${systemName}\")))[]" "${anodosysUserPath}/systems.json")

      if [[ -f "${configurationFile}" ]]; then
        configurationPath=$(dirname "${configurationFile}")
        configurationPathBasename=$(basename "${configurationPath}")

        if [[ "${configurationPathBasename}" == "ads" ]]; then
          cd "$(dirname "${configurationPath}")"
        else
          cd "${configurationPath}"
        fi
      else
        >&2 echo "Configuration not found at: ${configurationFile}"
      fi
    else
      >&2 echo "Systems file not found at: ${anodosysUserPath}/systems.json"
    fi
  else
    >&2 echo "No system name defined"
  fi
else
  2>&1 echo "To use jump, source the script, i.e.:"
  2>&1 echo "source ads-jump mysystem"
fi
