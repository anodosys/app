#!/bin/bash -e

containerRecreate()
{
  local containerName="${1}"
  local imageName
  local networkName
  local parameters
  local aliases
  local alias
  local bindPorts
  local bindPortDefinition
  local portParts
  local internalPort
  local hostPort
  local volumeNames
  local volumeName
  local sourcePath
  local targetPath
  local targetUser
  local mode

  imageName=$(docker inspect -f "{{ json .Config }}" "${containerName}" | jq -r ".Image // empty")
  networkName=$(docker inspect -f "{{ json .NetworkSettings }}" "${containerName}" | jq -r ".Networks | keys[0]")
  parameters=( )
  aliases=( $(docker inspect -f "{{ json .NetworkSettings }}" "${containerName}" | jq -r ".Networks .${networkName} .Aliases[]" | head -n -1) )
  for alias in "${aliases[@]}"; do
    parameters+=("alias:${alias}")
  done
  bindPorts=( $(docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".HostConfig .PortBindings | keys[] // empty") )
  for bindPortDefinition in "${bindPorts[@]}"; do
    readarray -d / -t portParts < <(printf '%s' "${bindPortDefinition}")
    internalPort="${portParts[0]}"
    hostPort=$(docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".HostConfig .PortBindings .\"${bindPortDefinition}\"[0] .HostPort")
    parameters+=("port:${hostPort}:${internalPort}")
  done
  oldIFS="${IFS}"
  IFS=$'\n'
  volumeNames=( $(docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".Mounts[] .Name // empty") )
  IFS="${oldIFS}"
  for volumeName in "${volumeNames[@]}"; do
    sourcePath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".sourcePath // empty")
    targetPath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetPath // empty")
    targetUser=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetUser // empty")
    mode=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".mode // empty")
    if [[ -z "${targetUser}" ]]; then
      targetUser="local"
    fi
    if [[ -z "${mode}" ]]; then
      mode="r"
    fi
    parameters+=("volume:${sourcePath}:${targetPath}:${targetUser}:${mode}")
  done
  containerRemove "${containerName}"
  containerCreate "${imageName}" "${containerName}" "${networkName}" "${parameters[@]}"
}

# shellcheck disable=SC2034
typeset -fx containerRecreate
