#!/bin/bash -e

containerStart()
{
  local containerName="${1}"
  local useNamedVolumes="${2}"
  local serverNames="${3:-none}"
  local networkName="${4:-none}"
  local retry="${5:-0}"
  local skipPortsAvailable="${6:-false}"
  local follow="${7:-false}"
  local containerStartedCommand="${8:-false}"
  local result
  local mountingIssue
  local ports
  local counter
  local containerPorts
  local dockerNetworkConnectCommand
  local serverNameList
  local linkedContainerName

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
      if [[ "${serverNames}" != "none" ]] && [[ "${networkName}" != "none" ]]; then
        echo "Connecting container to network: ${networkName}"
        dockerNetworkConnectCommand="docker network connect"
        readarray -d , -t serverNameList < <(printf '%s' "${serverNames}")
        for serverName in "${serverNameList[@]}"; do
          linkedContainerName="${networkName}_${serverName}"
          if [[ "${linkedContainerName}" != "${containerName}" ]]; then
            dockerNetworkConnectCommand+=" --link ${networkName}_${serverName}:${serverName}"
          else
            dockerNetworkConnectCommand+=" --alias ${serverName}"
          fi
        done
        dockerNetworkConnectCommand+=" ${networkName} ${containerName}"
        bash -c "${dockerNetworkConnectCommand}"
      fi
      echo "Starting container: ${containerName}"
      result=$(docker start "${containerName}" 2>&1 | cat)
      if [[ "${result}" == "${containerName}" ]]; then
        echo "Successfully started container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
        if [[ "${follow}" == "true" ]]; then
          docker logs --follow "${containerName}" &
        fi
      else
        if [[ "${retry}" == 0 ]]; then
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
      if [[ "${containerStartedCommand}" != "false" ]]; then
        echo "Using started script for container: ${containerName} at: ${containerStartedCommand}"
        counter=0
        while [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerCommandQuiet "${containerName}" "${containerStartedCommand} && echo \"1\" || echo \"0\"") == 0 ]] && [[ "${counter}" -lt 120 ]]; do
          echo "Waiting for started script for container: ${containerName}" | sed $'s,.*,\e[1;30m&\e[m,'
          counter=$(( counter + 1 ))
          sleep 1
        done
        if [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerCommandQuiet "${containerName}" "${containerStartedCommand} && echo \"1\" || echo \"0\"") == 1 ]]; then
          echo "Started script has finished for container: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
        elif [[ $(containerRunning "${containerName}") == 1 ]]; then
          >&2 echo "Started script has not finished for container: ${containerName}"
          exit 1
        fi
      fi
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
            echo "All ports are available for container: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
          elif [[ $(containerRunning "${containerName}") == 1 ]]; then
            >&2 echo "Not all ports are available for container: ${containerName}"
            exit 1
          else
            if [[ "${retry}" -lt 20 ]]; then
              echo "Container not running: ${containerName}, try again"
              retry=$(( retry + 1 ))
              containerStart \
                "${containerName}" \
                "${useNamedVolumes}" \
                "${serverNames}" \
                "${networkName}" \
                "${retry}" \
                "${skipPortsAvailable}" \
                "${follow}" \
                "${containerStartedCommand}"
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
