#!/bin/bash -e

# Data volumes (server config containerDataVolumes, entries name:/path/in/container) hold data that has to outlive the
# container, for example the files of a database. They are named Docker volumes called <container>_<name> and labelled
# anodosys.data, so that remove, purge and erase keep them; they are only deleted by hand (docker volume rm). Docker
# fills an empty volume with the content of the image at that path when the container is created, so a database that
# was initialized in the image starts with its initial files.

dataVolumeName()
{
  local containerName="${1}"
  local name="${2}"

  echo "${containerName}_${name}"
}

# shellcheck disable=SC2034
typeset -fx dataVolumeName

dataVolumeEnsure()
{
  local volumeName="${1}"
  local systemName="${2}"
  local serverName="${3}"
  local result

  if [[ $(volumeExists "${volumeName}") == 1 ]]; then
    echo "Using existing data volume: ${volumeName}"
  else
    echo "Creating data volume: ${volumeName}"
    result=$(docker volume create \
      --label "anodosys.data=true" \
      --label "com.docker.compose.project=${systemName}" \
      --label "com.docker.compose.service=${serverName}" \
      "${volumeName}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully created data volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create data volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx dataVolumeEnsure

# echoes 1 if the volume is a data volume, which must not be removed together with its container
dataVolumeIs()
{
  local volumeName="${1}"

  if [[ $(docker volume inspect --format '{{ index .Labels "anodosys.data" }}' "${volumeName}" 2>/dev/null) == "true" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# shellcheck disable=SC2034
typeset -fx dataVolumeIs

# adds the mount of a data volume (name:/path/in/container) to the docker create or run command in the variable named
# by the first argument
dataVolumeMount()
{
  local -n dataVolumeCommand="${1}"
  local containerName="${2}"
  local systemName="${3}"
  local serverName="${4}"
  local dataVolume="${5}"
  local name
  local targetPath
  local volumeName

  IFS=: read -r name targetPath <<< "${dataVolume}"
  if [[ -z "${name}" ]] || [[ -z "${targetPath}" ]]; then
    >&2 echo "Invalid data volume: ${dataVolume}, expected name:/path/in/container"
    exit 1
  fi
  volumeName=$(dataVolumeName "${containerName}" "${name}")
  dataVolumeEnsure "${volumeName}" "${systemName}" "${serverName}"
  dataVolumeCommand+=" --mount type=volume,source=${volumeName},destination=${targetPath}"
}

# shellcheck disable=SC2034
typeset -fx dataVolumeMount
