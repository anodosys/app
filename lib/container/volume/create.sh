#!/bin/bash -e

containerVolumeCreate()
{
  local containerName="${1}"
  local namedVolume="${2:-false}"
  local sourcePath="${3}"
  local targetPath="${4}"
  local targetUser="${5:-local}"
  local mode="${6:-r}"
  local userId="${7}"
  local user="${8}"
  local groupId="${9}"
  local group="${10}"
  local rights="${11}"
  local empty="${12}"
  local sourceName
  local volumeName

  if [[ ! -e "${sourcePath}" ]]; then
    echo "Creating container volume source path: ${sourcePath}"
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

  if [[ -z "${userId}" ]] || [[ "${userId}" == "-" ]]; then
    userId=$(stat -c '%u' "${sourcePath}")
  fi
  if [[ -z "${user}" ]] || [[ "${user}" == "-" ]]; then
    user=$(stat -c '%U' "${sourcePath}")
  fi
  if [[ -z "${groupId}" ]] || [[ "${groupId}" == "-" ]]; then
    groupId=$(stat -c '%g' "${sourcePath}")
  fi
  if [[ -z "${group}" ]] || [[ "${group}" == "-" ]]; then
    group=$(stat -c '%G' "${sourcePath}")
  fi
  if [[ -z "${rights}" ]] || [[ "${rights}" == "-" ]]; then
    rights=$(stat -c '%a' "${sourcePath}")
  fi
  if [[ -z "${empty}" ]] || [[ "${empty}" == "-" ]]; then
    empty=$(find "${sourcePath}" -maxdepth 0 -empty | read -r && echo "true" || echo "false")
  fi

  if [[ $(volumeExists "${volumeName}") == 1 ]]; then
    volumeRemove "${volumeName}"
  fi

  volumeMetadataCreate "${sourcePath}" "${targetPath}" "${targetUser}" "${mode}" "${userId}" "${user}" "${groupId}" "${group}" "${rights}" "${empty}"
  if [[ "${namedVolume}" == "true" ]]; then
    volumeCreate "${volumeName}" "${sourcePath}" "${targetPath}" "${targetUser}" "${mode}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerVolumeCreate
