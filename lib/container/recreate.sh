#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

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
  local userId
  local user
  local groupId
  local group
  local rights
  local empty

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
    userId=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".userId // empty")
    user=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".user // empty")
    groupId=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".groupId // empty")
    group=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".group // empty")
    rights=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".rights // empty")
    empty=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".empty // empty")
    if [[ -z "${targetUser}" ]]; then
      targetUser="local"
    fi
    if [[ -z "${mode}" ]]; then
      mode="r"
    fi
    if [[ -z "${userId}" ]]; then
      userId="-"
    fi
    if [[ -z "${user}" ]]; then
      user="-"
    fi
    if [[ -z "${groupId}" ]]; then
      groupId="-"
    fi
    if [[ -z "${group}" ]]; then
      group="-"
    fi
    if [[ -z "${rights}" ]]; then
      rights="-"
    fi
    if [[ -z "${empty}" ]]; then
      empty="-"
    fi
    parameters+=("volume:${sourcePath}:${targetPath}:${targetUser}:${mode}:${userId}:${user}:${groupId}:${group}:${rights}:${empty}")
  done

  containerRemove "${containerName}"

  mkdir -p "${anodosysUserVarPath}/commencement"
  rm -rf "${anodosysUserVarPath}/commencement/${containerName}"
  mkdir -p "${anodosysUserVarPath}/production"
  rm -rf "${anodosysUserVarPath}/production/${containerName}"
  mkdir -p "${anodosysUserVarPath}/finishing"
  rm -rf "${anodosysUserVarPath}/finishing/${containerName}"

  containerCreate "${imageName}" "${containerName}" "${networkName}" "${parameters[@]}"
}

# shellcheck disable=SC2034
typeset -fx containerRecreate
