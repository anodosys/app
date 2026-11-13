#!/bin/bash -e

# ads proxy [start|stop|restart|update|status|remove|hosts]
#
# Manages the proxy that routes the host names of all systems on the host ports 80 and 443 (see lib/proxy/proxy.sh).
# The proxy is an Anodosys system itself, its configuration is written to <user var path>/proxy/<system>/ads.json.

if [[ -z "${anodosysPath}" ]]; then
  >&2 echo "No anodosys path defined"
  exit 1
fi

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path defined"
  exit 1
fi

proxyCommand="${2:-status}"
proxySystem=$(proxySystemName)
proxyContainer=$(proxyContainerName)
proxyPath="${anodosysUserVarPath}/proxy/${proxySystem}"
proxyConfigurationFile="${proxyPath}/ads.json"
proxyRoutes=$(proxyRoutesPath)
proxyStatusContainer="${proxySystem}_status"
proxyStatusPath="${proxyPath}/status"

# the status page reads the container list through the Docker socket of the host, the proxy runs without it when there is
# no socket at the usual place or in DOCKER_HOST
proxyDockerSocket=/var/run/docker.sock
if [[ "${DOCKER_HOST:-}" == unix://* ]]; then
  proxyDockerSocket="${DOCKER_HOST#unix://}"
fi
proxyServerNames=( proxy )
if [[ -S "${proxyDockerSocket}" ]]; then
  proxyServerNames+=( status )
fi

mkdir -p "${proxyRoutes}" "${proxyStatusPath}"
proxyDashboardWrite
# the files of the status page are copied on every call, so that a new Anodosys release also updates the page
cp "${anodosysAppPath}/proxy/status/index.html" "${anodosysAppPath}/proxy/status/nginx.conf" \
  "${anodosysAppPath}/proxy/status/install.sh" "${proxyStatusPath}/"

# the installation command of every server is written into its container after it ran, a server that was installed with
# another command is installed again by proxyUpdate (start, restart, update); the commands must not contain quotes, j2v
# writes them unescaped into the server configuration
declare -A proxyInstallCommands=(
  [proxy]="cosyses Traefik 3.7 --dynamicPath /etc/traefik/dynamic --dashboard yes"
  [status]="cosyses Nginx 1.30 && bash /etc/anodosys-status/install.sh"
)
declare -A proxyInstallMarkers=(
  [proxy]="/etc/traefik/anodosys-install"
  [status]="/etc/anodosys-install"
)

# the configuration is written on every call, so that a new Anodosys release also updates the proxy
jq -n \
  --arg system "${proxySystem}" \
  --argjson serverNames "$(printf '%s\n' "${proxyServerNames[@]}" | jq -R . | jq -s .)" \
  --arg proxyInstall "${proxyInstallCommands[proxy]} && echo '${proxyInstallCommands[proxy]}' > ${proxyInstallMarkers[proxy]}" \
  --arg statusInstall "${proxyInstallCommands[status]} && echo '${proxyInstallCommands[status]}' > ${proxyInstallMarkers[status]}" \
  --arg httpPort "${ANODOSYS_PROXY_HTTP_PORT:-80}" \
  --arg httpsPort "${ANODOSYS_PROXY_HTTPS_PORT:-443}" \
  --arg routes "${proxyRoutes}" \
  --arg socket "${proxyDockerSocket}" \
  --arg user "${anodosysUserPath}" \
  --arg status "${proxyStatusPath}" \
  '{
    global: {systemName: $system},
    system: {serverNames: $serverNames},
    proxy: {
      imageName: "cosyses/ubuntu",
      imageTag: "24.04",
      containerPortsFixed: "true",
      containerPorts: ["\($httpPort):80", "\($httpsPort):443"],
      containerVolumes: ["\($routes):/etc/traefik/dynamic"],
      containerInstall: $proxyInstall,
      containerStartedCommand: "/usr/local/bin/started.sh",
      skipPortsAvailable: "true"
    },
    status: {
      imageName: "cosyses/ubuntu",
      imageTag: "24.04",
      containerVolumes: [
        "\($socket):/var/run/docker.sock:www-data:r",
        "\($user):/anodosys:www-data:r",
        "\($status):/etc/anodosys-status:www-data:r"
      ],
      containerInstall: $statusInstall,
      containerStartedCommand: "/usr/local/bin/started.sh",
      skipPortsAvailable: "true"
    }
  }' > "${proxyConfigurationFile}"

# for testing a Cosyses routine before it is released: mounts a Cosyses checkout as the installation in the containers,
# use it together with ANODOSYS_PROXY_ENV=NO_COSYSES_UPDATE=1
if [[ -n "${ANODOSYS_PROXY_COSYSES_PATH}" ]]; then
  jq --arg cosyses "${ANODOSYS_PROXY_COSYSES_PATH}" '(.proxy, .status).containerVolumes += ["\($cosyses):/usr/local/lib/cosyses/current"]' \
    "${proxyConfigurationFile}" > "${proxyConfigurationFile}.tmp"
  mv "${proxyConfigurationFile}.tmp" "${proxyConfigurationFile}"
fi

# runs an action of the proxy system with a clean environment, so that no variable of the caller becomes a parameter
proxyRun()
{
  local proxyAction="${1}"
  shift
  local parameters=( "${proxyAction}" --fileName "${proxyConfigurationFile}" "$@" )

  # extra environment for the proxy container, for example NO_COSYSES_UPDATE=1
  if [[ -n "${ANODOSYS_PROXY_ENV}" ]]; then
    parameters+=( --env "${ANODOSYS_PROXY_ENV}" )
  fi

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
    "${anodosysPath}/anodosys.sh" "${parameters[@]}"
}

# host names of all routes, from the "# hosts:" line that proxyRoutesWrite writes into every route file; names below
# .localhost are left out, browsers resolve them without a hosts entry
proxyHostNames()
{
  find "${proxyRoutes}" -maxdepth 1 -name "*.yml" -exec sed -n 's/^# hosts: //p' {} \; | tr ' ' '\n' | sed '/^$/d; /\.localhost$/d' | sort -u
}

# creates a server of the proxy system whose container is missing, for example the status page of a proxy that was
# created before it existed; the software is installed into the running container, its start script runs with the next
# start
proxyServerCreate()
{
  local serverName="${1}"

  echo "Creating ${serverName} of proxy: ${proxySystem}_${serverName}" | sed $'s,.*,\e[1;37m&\e[m,'
  proxyRun rise --server "${serverName}"
  proxyRun stop --server "${serverName}"
  proxyRun start --server "${serverName}"
}

# brings a running proxy up to date: creates missing servers, installs a server again when it was installed with another
# command than in proxyInstallCommands (for example before the dashboard existed) and restarts it, so that the new
# configuration is read, and reloads the configuration of the status page
proxyUpdate()
{
  local serverName
  local containerName
  local installed
  local command

  if [[ $(containerRunning "${proxyContainer}") == 0 ]]; then
    return 0
  fi

  for serverName in "${proxyServerNames[@]}"; do
    containerName="${proxySystem}_${serverName}"
    if [[ $(containerExists "${containerName}") == 0 ]]; then
      proxyServerCreate "${serverName}"
      continue
    fi
    if [[ $(containerRunning "${containerName}") == 0 ]]; then
      proxyRun start --server "${serverName}"
    fi
    command="${proxyInstallCommands[${serverName}]}"
    installed=$(docker exec "${containerName}" cat "${proxyInstallMarkers[${serverName}]}" 2>/dev/null || true)
    if [[ "${installed}" != "${command}" ]]; then
      echo "Updating ${serverName} of proxy: ${containerName}" | sed $'s,.*,\e[1;37m&\e[m,'
      # the Cosyses of a container that runs for a while can be older than the routine, NO_COSYSES_UPDATE keeps a checkout
      # mounted for testing
      docker exec "${containerName}" bash -c "if [[ -z \"\${NO_COSYSES_UPDATE}\" ]]; then cosyses update; fi && ${command} && echo '${command}' > ${proxyInstallMarkers[${serverName}]}"
      proxyRun stop --server "${serverName}"
      proxyRun start --server "${serverName}"
    fi
  done

  if [[ $(containerRunning "${proxyStatusContainer}") == 1 ]]; then
    docker exec "${proxyStatusContainer}" nginx -s reload >/dev/null 2>&1 || true
  fi
}

# the address of the status page (the Traefik dashboard is below dashboard/), with the port when the proxy does not use
# port 80
proxyDashboardUrl()
{
  local port="${ANODOSYS_PROXY_HTTP_PORT:-80}"

  if [[ "${port}" == 80 ]]; then
    echo "http://$(proxyDashboardHost)/"
  else
    echo "http://$(proxyDashboardHost):${port}/"
  fi
}

# creates the missing servers of the proxy system, starts the stopped ones and brings them up to date
proxyStartServers()
{
  local serverName
  local containerName

  for serverName in "${proxyServerNames[@]}"; do
    containerName="${proxySystem}_${serverName}"
    if [[ $(containerExists "${containerName}") == 0 ]]; then
      proxyServerCreate "${serverName}"
    elif [[ $(containerRunning "${containerName}") == 0 ]]; then
      echo "Starting ${serverName} of proxy: ${containerName}" | sed $'s,.*,\e[1;37m&\e[m,'
      proxyRun start --server "${serverName}"
    else
      echo "Proxy ${serverName} is already running: ${containerName}"
    fi
  done
  proxyUpdate
}

# stops the running servers of the proxy system
proxyStopServers()
{
  local serverName

  for serverName in "${proxyServerNames[@]}"; do
    if [[ $(containerRunning "${proxySystem}_${serverName}") == 1 ]]; then
      proxyRun stop --server "${serverName}"
    fi
  done
}

case "${proxyCommand}" in
  start)
    proxyStartServers
    ;;
  stop)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]] || [[ $(containerRunning "${proxyStatusContainer}") == 1 ]]; then
      proxyStopServers
    else
      echo "Proxy is not running: ${proxyContainer}"
    fi
    ;;
  restart)
    proxyStopServers
    proxyStartServers
    ;;
  update)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]]; then
      proxyUpdate
      echo "Proxy is up to date: ${proxyContainer}"
    else
      echo "Proxy is not running: ${proxyContainer}"
    fi
    ;;
  remove)
    if [[ $(containerExists "${proxyContainer}") == 1 ]] && [[ $(containerExists "${proxyStatusContainer}") == 1 ]]; then
      proxyRun purge
    elif [[ $(containerExists "${proxyContainer}") == 1 ]]; then
      proxyRun purge --server proxy
    elif [[ $(containerExists "${proxyStatusContainer}") == 1 ]]; then
      proxyRun purge --server status
    else
      echo "Proxy does not exist: ${proxyContainer}"
    fi
    ;;
  status)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]]; then
      echo "Proxy is running: ${proxyContainer} (http: ${ANODOSYS_PROXY_HTTP_PORT:-80}, https: ${ANODOSYS_PROXY_HTTPS_PORT:-443})"
      if [[ $(containerRunning "${proxyStatusContainer}") == 1 ]]; then
        echo "Status page: $(proxyDashboardUrl)"
      else
        echo "Status page: not running (${proxyStatusContainer}), create it with: ads proxy update"
      fi
      echo "Dashboard: $(proxyDashboardUrl)dashboard/"
    elif [[ $(containerExists "${proxyContainer}") == 1 ]]; then
      echo "Proxy is stopped: ${proxyContainer}"
    else
      echo "Proxy does not exist: ${proxyContainer}, it is created with the first system that uses proxyHosts or with: ads proxy start"
    fi
    echo ""
    echo "route                               | host names"
    echo "----------------------------------- | ----------"
    for routesFile in "${proxyRoutes}"/*.yml; do
      if [[ -f "${routesFile}" ]]; then
        printf '%-35s | %s\n' "$(basename "${routesFile}" .yml)" "$(sed -n 's/^# hosts: //p' "${routesFile}")"
      fi
    done
    ;;
  hosts)
    # the host names have to point to this machine, prints the lines missing in the hosts files
    hostsFiles=( /etc/hosts )
    if [[ -f /mnt/c/Windows/System32/drivers/etc/hosts ]]; then
      hostsFiles+=( /mnt/c/Windows/System32/drivers/etc/hosts )
    fi
    for hostsFile in "${hostsFiles[@]}"; do
      missing=()
      while read -r hostName; do
        if ! grep -Eq "^[^#]*[[:space:]]${hostName//./\\.}([[:space:]]|$)" "${hostsFile}"; then
          missing+=( "${hostName}" )
        fi
      done < <(proxyHostNames)
      if [[ "${#missing[@]}" -gt 0 ]]; then
        echo "Add to: ${hostsFile}" | sed $'s,.*,\e[1;37m&\e[m,'
        for hostName in "${missing[@]}"; do
          echo "127.0.0.1 ${hostName}"
        done
      else
        echo "All host names are in: ${hostsFile}" | sed $'s,.*,\e[0;32m&\e[m,'
      fi
    done
    ;;
  *)
    >&2 echo "Unknown proxy command: ${proxyCommand}, use start, stop, restart, update, status, remove or hosts"
    exit 1
    ;;
esac
