#!/bin/bash -e

# ads proxy [start|stop|restart|update|status|remove|hosts]
#
# Manages the proxy that routes the host names of all systems on the host ports 80 and 443 (see lib/proxy/proxy.sh).
# The proxy is an Anodosys system itself, its configuration is written to <user var path>/proxy/<system>/ads.json.

if [[ -z "${anodosysPath}" ]]; then
  >&2 echo "No anodosys path defined"
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

mkdir -p "${proxyRoutes}"
proxyDashboardWrite

# the installation command is written into the container after it ran, an existing proxy that was installed with another
# command is installed again by proxyUpdate (start, restart, update)
proxyInstallCommand="cosyses Traefik 3.7 --dynamicPath /etc/traefik/dynamic --dashboard yes"
proxyInstallMarker="/etc/traefik/anodosys-install"

# the configuration is written on every call, so that a new Anodosys release also updates the proxy
jq -n \
  --arg system "${proxySystem}" \
  --arg install "${proxyInstallCommand} && echo '${proxyInstallCommand}' > ${proxyInstallMarker}" \
  --arg httpPort "${ANODOSYS_PROXY_HTTP_PORT:-80}" \
  --arg httpsPort "${ANODOSYS_PROXY_HTTPS_PORT:-443}" \
  --arg routes "${proxyRoutes}" \
  '{
    global: {systemName: $system},
    system: {serverNames: ["proxy"]},
    proxy: {
      imageName: "cosyses/ubuntu",
      imageTag: "24.04",
      containerPortsFixed: "true",
      containerPorts: ["\($httpPort):80", "\($httpsPort):443"],
      containerVolumes: ["\($routes):/etc/traefik/dynamic"],
      containerInstall: $install,
      containerStartedCommand: "/usr/local/bin/started.sh",
      skipPortsAvailable: "true"
    }
  }' > "${proxyConfigurationFile}"

# for testing a Cosyses routine before it is released: mounts a Cosyses checkout as the installation in the container,
# use it together with ANODOSYS_PROXY_ENV=NO_COSYSES_UPDATE=1
if [[ -n "${ANODOSYS_PROXY_COSYSES_PATH}" ]]; then
  jq --arg cosyses "${ANODOSYS_PROXY_COSYSES_PATH}" '.proxy.containerVolumes += ["\($cosyses):/usr/local/lib/cosyses/current"]' \
    "${proxyConfigurationFile}" > "${proxyConfigurationFile}.tmp"
  mv "${proxyConfigurationFile}.tmp" "${proxyConfigurationFile}"
fi

# runs an action of the proxy system with a clean environment, so that no variable of the caller becomes a parameter
proxyRun()
{
  local proxyAction="${1}"
  local parameters=( "${proxyAction}" --fileName "${proxyConfigurationFile}" )

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

# installs Traefik again in the running proxy when it was installed with another command than proxyInstallCommand, for
# example before the dashboard existed, and restarts the proxy so that Traefik reads its new configuration
proxyUpdate()
{
  local installed

  if [[ $(containerRunning "${proxyContainer}") == 0 ]]; then
    return 0
  fi

  installed=$(docker exec "${proxyContainer}" cat "${proxyInstallMarker}" 2>/dev/null || true)
  if [[ "${installed}" == "${proxyInstallCommand}" ]]; then
    return 0
  fi

  echo "Updating proxy: ${proxyContainer}" | sed $'s,.*,\e[1;37m&\e[m,'
  # the Cosyses of a container that runs for a while can be older than the routine, NO_COSYSES_UPDATE keeps a checkout
  # mounted for testing
  docker exec "${proxyContainer}" bash -c "if [[ -z \"\${NO_COSYSES_UPDATE}\" ]]; then cosyses update; fi && ${proxyInstallCommand} && echo '${proxyInstallCommand}' > ${proxyInstallMarker}"
  proxyRun stop
  proxyRun start
}

# the address of the dashboard, with the port when the proxy does not use port 80
proxyDashboardUrl()
{
  local port="${ANODOSYS_PROXY_HTTP_PORT:-80}"

  if [[ "${port}" == 80 ]]; then
    echo "http://$(proxyDashboardHost)/"
  else
    echo "http://$(proxyDashboardHost):${port}/"
  fi
}

case "${proxyCommand}" in
  start)
    if [[ $(containerExists "${proxyContainer}") == 0 ]]; then
      echo "Creating proxy: ${proxyContainer}" | sed $'s,.*,\e[1;37m&\e[m,'
      proxyRun rise
      # Traefik is installed into the running container, its start script runs with the next container start
      proxyRun stop
      proxyRun start
    elif [[ $(containerRunning "${proxyContainer}") == 0 ]]; then
      echo "Starting proxy: ${proxyContainer}" | sed $'s,.*,\e[1;37m&\e[m,'
      proxyRun start
      proxyUpdate
    else
      echo "Proxy is already running: ${proxyContainer}"
      proxyUpdate
    fi
    ;;
  stop)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]]; then
      proxyRun stop
    else
      echo "Proxy is not running: ${proxyContainer}"
    fi
    ;;
  restart)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]]; then
      proxyRun stop
    fi
    proxyRun start
    proxyUpdate
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
    if [[ $(containerExists "${proxyContainer}") == 1 ]]; then
      proxyRun purge
    else
      echo "Proxy does not exist: ${proxyContainer}"
    fi
    ;;
  status)
    if [[ $(containerRunning "${proxyContainer}") == 1 ]]; then
      echo "Proxy is running: ${proxyContainer} (http: ${ANODOSYS_PROXY_HTTP_PORT:-80}, https: ${ANODOSYS_PROXY_HTTPS_PORT:-443})"
      echo "Dashboard: $(proxyDashboardUrl)"
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
