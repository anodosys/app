#!/bin/bash -e
# shellcheck disable=SC2154

# Host ports of all systems are assigned in <user var path>/ports.json, so that several systems can run at the same time
# and a system keeps its ports: the first system that requests a host port keeps it, a later request for a taken port
# gets the next free one, and every assignment is kept, also when the container is removed.

portRegistryFile()
{
  echo "${anodosysUserVarPath}/ports.json"
}

# shellcheck disable=SC2034
typeset -fx portRegistryFile

# host ports that containers of other systems bind or request, also stopped ones and those created before the registry
portRegistryForeignPorts()
{
  local systemName="${1}"

  docker ps -a -q | xargs -r docker inspect --format '{{ json . }}' 2>/dev/null \
    | jq -r --arg project "${systemName}" \
      'select((.Config.Labels["com.docker.compose.project"] // "") != $project)
        | .HostConfig.PortBindings // {} | to_entries[] | .value[]? | .HostPort | select(. != null and . != "")'
}

# shellcheck disable=SC2034
typeset -fx portRegistryForeignPorts

# returns the host port assigned to a container port, without assigning one: portRegistryLookup <system> <server>
# <container port>
portRegistryLookup()
{
  local systemName="${1}"
  local serverName="${2}"
  local containerPort="${3}"
  local registryFile

  registryFile=$(portRegistryFile)

  if [[ -f "${registryFile}" ]]; then
    jq -r --arg key "${systemName}/${serverName}/${containerPort}" '.[$key] // empty' "${registryFile}"
  fi
}

# shellcheck disable=SC2034
typeset -fx portRegistryLookup

# returns the host port for a requested one, assigns and stores it if needed: portRegistryAssign <system> <server>
# <container port> <requested host port>
portRegistryAssign()
{
  local systemName="${1}"
  local serverName="${2}"
  local containerPort="${3}"
  local requestedPort="${4}"
  local registryFile
  local key
  local hostPort
  local takenPorts

  registryFile=$(portRegistryFile)
  key="${systemName}/${serverName}/${containerPort}"

  (
    # servers are created in parallel, so the registry is locked while a port is assigned
    flock 9

    if [[ ! -f "${registryFile}" ]]; then
      echo "{}" > "${registryFile}"
    fi

    hostPort=$(jq -r --arg key "${key}" '.[$key] // empty' "${registryFile}")

    if [[ -z "${hostPort}" ]]; then
      readarray -t takenPorts < <(
        jq -r --arg key "${key}" 'to_entries[] | select(.key != $key) | .value | tostring' "${registryFile}"
        portRegistryForeignPorts "${systemName}"
      )

      hostPort="${requestedPort}"
      while printf '%s\n' "${takenPorts[@]}" | grep -qx "${hostPort}"; do
        hostPort=$((hostPort + 1))
      done

      jq --arg key "${key}" --argjson port "${hostPort}" '. + {($key): $port}' "${registryFile}" > "${registryFile}.tmp"
      mv "${registryFile}.tmp" "${registryFile}"

      if [[ "${hostPort}" != "${requestedPort}" ]]; then
        >&2 echo "Host port: ${requestedPort} is used by another system, assigned host port: ${hostPort} to: ${key}"
      fi
    fi

    echo "${hostPort}"
  ) 9>"${registryFile}.lock"
}

# shellcheck disable=SC2034
typeset -fx portRegistryAssign

# returns a container port specification ([ip:]host:container[/protocol]) with the assigned host port:
# portRegistryResolve <system> <server> <specification>
portRegistryResolve()
{
  local systemName="${1}"
  local serverName="${2}"
  local specification="${3}"
  local protocol=
  local parts
  local hostIp=
  local hostPort
  local containerPort

  if [[ "${specification}" == */* ]]; then
    protocol="/${specification##*/}"
    specification="${specification%/*}"
  fi

  readarray -d : -t parts < <(printf '%s' "${specification}")

  if [[ "${#parts[@]}" -eq 3 ]]; then
    hostIp="${parts[0]}:"
    hostPort="${parts[1]}"
    containerPort="${parts[2]}"
  elif [[ "${#parts[@]}" -eq 2 ]]; then
    hostPort="${parts[0]}"
    containerPort="${parts[1]}"
  else
    # only a container port, Docker picks the host port
    echo "${specification}${protocol}"
    return 0
  fi

  if [[ ! "${hostPort}" =~ ^[0-9]+$ ]]; then
    echo "${hostIp}${hostPort}:${containerPort}${protocol}"
    return 0
  fi

  hostPort=$(portRegistryAssign "${systemName}" "${serverName}" "${containerPort}${protocol}" "${hostPort}")
  echo "${hostIp}${hostPort}:${containerPort}${protocol}"
}

# shellcheck disable=SC2034
typeset -fx portRegistryResolve
