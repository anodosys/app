#!/bin/bash -e

containerStart()
{
  local containerName="${1}"
  local useNamedVolumes="${2}"
  local networkName="${3}"
  local retry="${4:-no}"
  local skipPortsAvailable="${5:-false}"
  local follow="${6:-false}"
  local result
  local mountingIssue
  local ports
  local counter
  local containerPorts

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ $(containerRunning "${containerName}") == 0 ]]; then
      containerPorts=( $(containerPortHostList "${containerName}") )
      if [[ "${#containerPorts[@]}" -gt 0 ]]; then
        echo "Checking if ports: ${containerPorts[*]} are blocked for container: ${containerName}"
        if [[ $(containerPortBlocked "${containerName}") == 1 ]]; then
          >&2 echo "Cannot start container because ports: ${containerPorts[*]} are blocked"
          exit 1
        fi
      fi
      containerVolumeCheck "${containerName}"
      echo "Connecting container to network: ${networkName}"
      docker network connect "${networkName}" "${containerName}"
      echo "Starting container: ${containerName}"
      result=$(docker start "${containerName}" 2>&1 | cat)
      if [[ "${result}" == "${containerName}" ]]; then
        echo "Successfully started container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
        if [[ "${follow}" == "true" ]]; then
          docker logs --follow "${containerName}" &
        fi
      else
        if [[ "${retry}" == "no" ]]; then
          mountingIssue=$(echo "${result}" | grep "error while mounting volume" | wc -l)
          if [[ "${mountingIssue}" -gt 0 ]]; then
            >&2 echo "Container has mounting issue"
            exit 1
          fi
        fi
        >&2 echo "Could not start container: ${containerName}"
        >&2 echo "${result}"
        exit 1
      fi
      containerVolumePrepare "${containerName}" "${useNamedVolumes}"
      containerHostNameAdd "${containerName}"
      if [[ "${skipPortsAvailable}" == "false" ]]; then
        ports=( $(containerPortList "${containerName}") )
        if [[ "${#ports[@]}" -gt 0 ]]; then
          for port in "${ports[@]}"; do
            readarray -d / -t portParts < <(printf '%s' "${port}")
            port="${portParts[0]}"
            protocol="${portParts[1]}"
            echo "Waiting until port: ${port} with protocol: ${protocol} is available"
          done
          echo "Checking if all ports are available for container: ${containerName}"
          counter=0
          while [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerPortAvailable "${containerName}") == 0 ]] && [[ "${counter}" -lt 120 ]]; do
            echo "Waiting until ports are available for container: ${containerName}" | sed $'s,.*,\e[1;30m&\e[m,'
            counter=$(( counter + 1 ))
            sleep 1
          done
          if [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerPortAvailable "${containerName}") == 1 ]]; then
            echo "All ports are available for containerName: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
          elif [[ $(containerRunning "${containerName}") == 1 ]]; then
            >&2 echo "Not all ports are available for container: ${containerName}"
            exit 1
          else
            if [[ "${retry}" == "no" ]]; then
              echo "Container not running: ${containerName}, try again"
              containerStart "${containerName}" "${useNamedVolumes}" "${networkName}" "yes" "${skipPortsAvailable}" "${follow}"
            else
              >&2 echo "Container not running: ${containerName}"
              exit 1
            fi
          fi
        fi
      else
        echo "Skipping checking for ports available"
      fi
    else
      echo "No need to start container: ${containerName}"
    fi
  else
    >&2 echo "Container does not exist: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerStart
