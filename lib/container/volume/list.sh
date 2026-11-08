#!/bin/bash -e

# prints name and source path of every mount of the container, separated by a unit separator (\x1f, not whitespace, so
# that the empty name of a bind mount is kept), without the data volumes
# (containerDataVolumes): they have no metadata and are never prepared, checked or removed together with the container
containerVolumeMountList()
{
  local containerName="${1}"
  local name
  local source

  while IFS=$'\x1f' read -r name source; do
    if [[ -n "${name}" ]] && [[ $(dataVolumeIs "${name}") == 1 ]]; then
      continue
    fi
    printf '%s\x1f%s\n' "${name}" "${source}"
  done < <(docker inspect -f "{{ json .Mounts }}" "${containerName}" | jq -r '.[] | (.Name // "") + "\u001f" + (.Source // "")')
}

# shellcheck disable=SC2034
typeset -fx containerVolumeMountList

containerVolumeNameList()
{
  local containerName="${1}"

  containerVolumeMountList "${containerName}" | cut -d $'\x1f' -f1 | sed '/^$/d'
}

# shellcheck disable=SC2034
typeset -fx containerVolumeNameList

containerVolumeSourcePathList()
{
  local containerName="${1}"

  containerVolumeMountList "${containerName}" | cut -d $'\x1f' -f2 | sed '/^$/d'
}

# shellcheck disable=SC2034
typeset -fx containerVolumeSourcePathList
