#!/bin/bash -e

containerVolumeCreate()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-local}"
  local mode="${5:-r}"
  local sourceName
  local volumeName

  if [[ ! -e "${sourcePath}" ]]; then
    echo "Creating source path: ${sourcePath}"
    mkdir -p "${sourcePath}" | cat
    if [[ -d "${sourcePath}" ]]; then
      echo "Successfully created source path: ${sourcePath}" | sed $'s,.*,\e[1;36m&\e[m,'
      chmod 0775 "${sourcePath}"
      if [[ $(stat -c '%a' "${sourcePath}") == "775" ]]; then
        echo "Successfully changed access rights of source path: ${sourcePath} to 0775" | sed $'s,.*,\e[1;36m&\e[m,'
      else
        >&2 echo "Could not change access rights of source path: ${sourcePath} to 0775"
        exit 1
      fi
    else
      >&2 echo "Could not create source path: ${sourcePath}"
      exit 1
    fi
  fi
  sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
  volumeName="${containerName}_${sourceName}"
  volumeCreate "${volumeName}" "${sourcePath}" "${targetPath}" "${targetUser}" "${mode}"
}

# shellcheck disable=SC2034
typeset -fx containerVolumeCreate
