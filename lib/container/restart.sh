#!/bin/bash -e

containerRestart()
{
  local containerName="${1}"
  local useNamedVolumes="${2}"
  local retry="${3:-no}"
  local skipPortsAvailable="${4:-false}"
  local follow="${5:-false}"
  local result
  local ports
  local counter

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Restarting container: ${containerName}"
    result=$(docker restart "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully restarted container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
      if [[ "${follow}" == "true" ]]; then
        docker logs --follow "${containerName}" &
      fi
      if [[ "${skipPortsAvailable}" == "false" ]]; then
        ports=( $(containerPortList "${containerName}") )
        if [[ "${#ports[@]}" -gt 0 ]]; then
          echo "Checking if all ports are available: ${containerName}"
          counter=0
          while [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerPortAvailable "${containerName}") == 0 ]] && [[ "${counter}" -lt 120 ]]; do
            echo "Waiting until ports are available for container: ${containerName}" | sed $'s,.*,\e[1;30m&\e[m,'
            counter=$(( counter + 1 ))
            sleep 1
          done
          if [[ $(containerRunning "${containerName}") == 1 ]] && [[ $(containerPortAvailable "${containerName}") == 1 ]]; then
            echo "All ports are available for containerName: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
          elif [[ $(containerRunning "${containerName}") == 1 ]]; then
            >&2 echo "Not all ports are available for containerName: ${containerName}"
            exit 1
          else
            if [[ "${retry}" == "no" ]]; then
              echo "Container not running: ${containerName}, try again"
              containerRestart "${containerName}" "${useNamedVolumes}" "yes" "${skipPortsAvailable}" "${follow}"
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
      >&2 echo "Could not restart container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to restart container: ${containerName}, starting container"
    containerStart "${containerName}" "${useNamedVolumes}" "${retry}" "${skipPortsAvailable}" "${follow}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerRestart
