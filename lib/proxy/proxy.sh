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

  # servers are prepared in parallel and several systems can start at the same time, ads proxy start locks itself, so
  # only one of them creates the servers of the proxy while the others wait and find them running
  proxyStart
}

# shellcheck disable=SC2034
typeset -fx proxyEnsure

proxyStart()
{
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
typeset -fx proxyStart

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
#
# a host name that the route of another running container already has stays with that container, Traefik would
# otherwise pick one of the two routers and the site silently switches to the newer one; routes of containers that are
# not running are left over (their containers write them again when they start) and are removed. Servers of several
# systems start at the same time, so the routes are locked while they are checked and written.
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
  local routesFile

  routesPath=$(proxyRoutesPath)
  mkdir -p "${routesPath}"
  routeName="${systemName}_${serverName}"
  routesFile="${routesPath}/${routeName}.yml"

  (
    flock 9

    local otherFile
    local otherContainer
    local otherHosts
    local hostName
    local claimedHosts=()
    local rule

    for otherFile in "${routesPath}"/*.yml; do
      if [[ ! -f "${otherFile}" ]] || [[ "${otherFile}" == "${routesFile}" ]]; then
        continue
      fi
      otherContainer=$(sed -n 's/^# written by Anodosys for container: //p' "${otherFile}")
      # the dashboard route belongs to the proxy itself
      if [[ -z "${otherContainer}" ]]; then
        continue
      fi
      otherHosts=" $(sed -n 's/^# hosts: //p' "${otherFile}") "
      for hostName in "${hostNames[@]}"; do
        if [[ "${otherHosts}" != *" ${hostName} "* ]]; then
          continue
        fi
        if [[ $(containerRunning "${otherContainer}") == 1 ]]; then
          echo "Host name: ${hostName} is routed to running container: ${otherContainer}, not to: ${containerName}; stop ${otherContainer} and start ${containerName} again to move it" | sed $'s,.*,\e[0;33m&\e[m,'
          claimedHosts+=( "${hostName}" )
        else
          echo "Removing left-over proxy routes of stopped container: ${otherContainer} in: ${otherFile}"
          rm -f "${otherFile}"
          break
        fi
      done
    done

    rule=
    local freeHosts=()
    for hostName in "${hostNames[@]}"; do
      if [[ " ${claimedHosts[*]} " != *" ${hostName} "* ]]; then
        freeHosts+=( "${hostName}" )
        rule+="${rule:+ || }Host(\`${hostName}\`)"
      fi
    done

    if [[ "${#freeHosts[@]}" -eq 0 ]]; then
      echo "No host name left for container: ${containerName}, it gets no proxy routes" | sed $'s,.*,\e[0;33m&\e[m,'
      rm -f "${routesFile}"
      exit 0
    fi

    echo "Writing proxy routes for host names: ${freeHosts[*]} to: ${routesFile}"
    proxyRoutesFileWrite "${routesFile}" "${routeName}" "${containerName}" "${httpPort}" "${httpsPort}" "${rule}" "${freeHosts[*]}"
  ) 9>"${routesPath}.lock"
}

# shellcheck disable=SC2034
typeset -fx proxyRoutesWrite

# proxyRoutesFileWrite <file> <route name> <container> <http port> <https port> <rule> <host names>
proxyRoutesFileWrite()
{
  local routesFile="${1}"
  local routeName="${2}"
  local containerName="${3}"
  local httpPort="${4}"
  local httpsPort="${5}"
  local rule="${6}"
  local hostList="${7}"

  {
    echo "# written by Anodosys for container: ${containerName}"
    echo "# hosts: ${hostList}"
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
typeset -fx proxyRoutesFileWrite

# host name of the Traefik dashboard; browsers resolve every name below .localhost to this machine without a hosts entry
proxyDashboardHost()
{
  echo "$(proxySystemName).localhost"
}

# shellcheck disable=SC2034
typeset -fx proxyDashboardHost

# writes the routes of the dashboard host: the status page of Anodosys (container <proxy system>_status, port 8080) at
# "/", the Traefik dashboard and its API (service api@internal) below /dashboard/ and /api/; the longer rule of the
# dashboard router wins over the status page
proxyDashboardWrite()
{
  local routesPath
  local routeName
  local hostName
  local routesFile

  routesPath=$(proxyRoutesPath)
  mkdir -p "${routesPath}"
  routeName="$(proxySystemName)_dashboard"
  hostName=$(proxyDashboardHost)
  routesFile="${routesPath}/${routeName}.yml"

  {
    echo "# written by Anodosys for the status page and the dashboard of the proxy"
    echo "# hosts: ${hostName}"
    echo "http:"
    echo "  routers:"
    echo "    ${routeName}:"
    echo "      rule: \"Host(\`${hostName}\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))\""
    echo "      entryPoints: [web]"
    echo "      service: api@internal"
    echo "    $(proxySystemName)_status:"
    echo "      rule: \"Host(\`${hostName}\`)\""
    echo "      entryPoints: [web]"
    echo "      service: $(proxySystemName)_status"
    echo "  services:"
    echo "    $(proxySystemName)_status:"
    echo "      loadBalancer:"
    echo "        servers:"
    echo "          - url: \"http://$(proxySystemName)_status:8080\""
  } > "${routesFile}.tmp"
  mv "${routesFile}.tmp" "${routesFile}"
}

# shellcheck disable=SC2034
typeset -fx proxyDashboardWrite

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

  # a container created before its server used the proxy may still publish the ports of the proxy itself, it keeps
  # working that way until it is created again, because starting the proxy would take its ports
  if containerPortHostList "${containerName}" | grep -qxE "${ANODOSYS_PROXY_HTTP_PORT:-80}|${ANODOSYS_PROXY_HTTPS_PORT:-443}"; then
    echo "Container: ${containerName} publishes the ports of the proxy itself, create it again to use the proxy" | sed $'s,.*,\e[0;33m&\e[m,'
    return 0
  fi

  proxyEnsure
  proxyConnect "${containerName}"
  proxyRoutesWrite "${systemName}" "${serverName}" "${containerName}" "${httpPort}" "${httpsPort}" "${proxyHosts[@]}"
}

# shellcheck disable=SC2034
typeset -fx proxyServerPrepare
