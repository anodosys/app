#!/bin/bash -e
# shellcheck disable=SC2154

# The proxy is an Anodosys system of its own (system name "anodosys", server "proxy", container "anodosys_proxy") that
# runs Traefik on the host ports 80 and 443. Containers of other systems join its network and get a route file in
# <user var path>/proxy/routes, which Traefik watches. HTTP is routed by host name, HTTPS is passed through unchanged and
# routed by the server name (SNI), so the containers keep their own certificates.
#
# ANODOSYS_PROXY_SYSTEM, ANODOSYS_PROXY_HTTP_PORT and ANODOSYS_PROXY_HTTPS_PORT change the system name and the host
# ports, for example to run the smoke tests next to a running proxy.

proxySystemName()
{
  echo "${ANODOSYS_PROXY_SYSTEM:-anodosys}"
}

# shellcheck disable=SC2034
typeset -fx proxySystemName

proxyContainerName()
{
  echo "$(proxySystemName)_proxy"
}

# shellcheck disable=SC2034
typeset -fx proxyContainerName

proxyRoutesPath()
{
  echo "${anodosysUserVarPath}/proxy/$(proxySystemName)/routes"
}

# shellcheck disable=SC2034
typeset -fx proxyRoutesPath

# starts the proxy if it is not running, with a clean environment, so that no variable of the calling system is turned
# into a parameter of the proxy system
proxyEnsure()
{
  if [[ $(containerRunning "$(proxyContainerName)") == 1 ]]; then
    return 0
  fi

  echo "Starting proxy: $(proxyContainerName)"
  env -i \
    HOME="${HOME}" \
    USER="${USER}" \
    PATH="${PATH}" \
    LANG="${LANG:-C.UTF-8}" \
    TERM="${TERM:-dumb}" \
    anodosysBannerShown=1 \
    ANODOSYS_USER_PATH="${anodosysUserPath}" \
    ANODOSYS_PROXY_SYSTEM="${ANODOSYS_PROXY_SYSTEM:-}" \
    ANODOSYS_PROXY_HTTP_PORT="${ANODOSYS_PROXY_HTTP_PORT:-}" \
    ANODOSYS_PROXY_HTTPS_PORT="${ANODOSYS_PROXY_HTTPS_PORT:-}" \
    ANODOSYS_PROXY_ENV="${ANODOSYS_PROXY_ENV:-}" \
    ANODOSYS_PROXY_COSYSES_PATH="${ANODOSYS_PROXY_COSYSES_PATH:-}" \
    "${anodosysPath}/anodosys.sh" proxy start

  if [[ $(containerRunning "$(proxyContainerName)") == 0 ]]; then
    >&2 echo "Could not start proxy: $(proxyContainerName)"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx proxyEnsure

# connects a container to the network of the proxy, so that Traefik reaches it by its container name
proxyConnect()
{
  local containerName="${1}"
  local proxyNetwork

  proxyNetwork=$(proxySystemName)

  if [[ $(docker inspect -f "{{ json .NetworkSettings.Networks }}" "${containerName}" | jq -r --arg network "${proxyNetwork}" 'has($network)') == "true" ]]; then
    echo "Container: ${containerName} already connected to proxy network: ${proxyNetwork}"
  else
    echo "Connecting container: ${containerName} to proxy network: ${proxyNetwork}"
    docker network connect "${proxyNetwork}" "${containerName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx proxyConnect

# writes the Traefik routes of a container: proxyRoutesWrite <system> <server> <container> <http port> <https port>
# <host name>...; an empty port means that the container is not reached with that protocol
proxyRoutesWrite()
{
  local systemName="${1}"
  local serverName="${2}"
  local containerName="${3}"
  local httpPort="${4}"
  local httpsPort="${5}"
  shift 5
  local hostNames=( "$@" )
  local routesPath
  local routeName
  local rule
  local hostName
  local routesFile

  routesPath=$(proxyRoutesPath)
  mkdir -p "${routesPath}"
  routeName="${systemName}_${serverName}"
  routesFile="${routesPath}/${routeName}.yml"

  rule=
  for hostName in "${hostNames[@]}"; do
    rule+="${rule:+ || }Host(\`${hostName}\`)"
  done

  echo "Writing proxy routes for host names: ${hostNames[*]} to: ${routesFile}"
  {
    echo "# written by Anodosys for container: ${containerName}"
    echo "# hosts: ${hostNames[*]}"
    if [[ -n "${httpPort}" ]]; then
      echo "http:"
      echo "  routers:"
      echo "    ${routeName}:"
      echo "      rule: \"${rule}\""
      echo "      entryPoints: [web]"
      echo "      service: ${routeName}"
      echo "  services:"
      echo "    ${routeName}:"
      echo "      loadBalancer:"
      echo "        servers:"
      echo "          - url: \"http://${containerName}:${httpPort}\""
    fi
    if [[ -n "${httpsPort}" ]]; then
      echo "tcp:"
      echo "  routers:"
      echo "    ${routeName}:"
      echo "      rule: \"${rule//Host(/HostSNI(}\""
      echo "      entryPoints: [websecure]"
      echo "      service: ${routeName}"
      echo "      tls:"
      echo "        passthrough: true"
      echo "  services:"
      echo "    ${routeName}:"
      echo "      loadBalancer:"
      echo "        servers:"
      echo "          - address: \"${containerName}:${httpsPort}\""
    fi
  } > "${routesFile}.tmp"
  mv "${routesFile}.tmp" "${routesFile}"
}

# shellcheck disable=SC2034
typeset -fx proxyRoutesWrite

proxyRoutesRemove()
{
  local systemName="${1}"
  local serverName="${2}"
  local routesFile

  routesFile="$(proxyRoutesPath)/${systemName}_${serverName}.yml"

  if [[ -f "${routesFile}" ]]; then
    echo "Removing proxy routes: ${routesFile}"
    rm -f "${routesFile}"
  fi
}

# shellcheck disable=SC2034
typeset -fx proxyRoutesRemove

# connects the container and writes its routes when the server has proxy host names, used by the server scripts after
# creating or before starting a container: proxyServerPrepare <system> <server> <container>
proxyServerPrepare()
{
  local systemName="${1}"
  local serverName="${2}"
  local containerName="${3}"
  local httpPort
  local httpsPort

  # set by the server configuration
  # shellcheck disable=SC2154
  if [[ -z "${proxyHosts}" ]]; then
    return 0
  fi

  httpPort="${proxyHttpPort-80}"
  httpsPort="${proxyHttpsPort-}"

  proxyEnsure
  proxyConnect "${containerName}"
  proxyRoutesWrite "${systemName}" "${serverName}" "${containerName}" "${httpPort}" "${httpsPort}" "${proxyHosts[@]}"
}

# shellcheck disable=SC2034
typeset -fx proxyServerPrepare
