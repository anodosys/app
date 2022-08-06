#!/bin/bash -e

containerStart()
{
  local containerName="${1}"
  local retry="${2:-no}"
  local result
  local mountingIssue
  local ports
  local counter

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ $(containerRunning "${containerName}") == 0 ]]; then
      containerVolumeCheck "${containerName}"
      echo "Starting container: ${containerName}"
      result=$(docker start "${containerName}" 2>&1 | cat)
      if [[ "${result}" == "${containerName}" ]]; then
        echo "Successfully started container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
      else
        if [[ "${retry}" == "no" ]]; then
          mountingIssue=$(echo "${result}" | grep "error while mounting volume" | wc -l)
          if [[ "${mountingIssue}" -gt 0 ]]; then
            echo "Container has mounting issue"
            containerRecreate "${containerName}"
            containerStart "${containerName}" "yes"
            exit 0
          fi
        fi
        >&2 echo "Could not start container: ${containerName}"
        >&2 echo "${result}"
        exit 1
      fi
      containerVolumePrepare "${containerName}"
      containerHostNameAdd "${containerName}"
      ports=( $(containerPortList "${containerName}") )
      if [[ "${#ports[@]}" -gt 0 ]]; then
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
            containerStart "${containerName}" "yes"
          else
            >&2 echo "Container not running: ${containerName}"
            exit 1
          fi
        fi
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
