#!/bin/bash -e

finish()
{
  local lastExitCode
  local processId
  local sessionId
  local subProcessIds
  local subProcessId
  local runningProcessIds
  local runningProcessId

  if [[ "${action}" != "construct" ]] && [[ "${action}" != "reset" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "volumes" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "list" ]]; then
    lastExitCode=$?
    processId=$$
    sessionId=$(ps -o sid= -p ${processId})
    sessionId=$(prepareValue "${sessionId}")
    if [[ -n "${sessionId}" ]]; then
      subProcessIds=( $(ps --forest -o pid,cmd -g "${sessionId}" | tail -n +2 | grep -e "[[:space:]]*[0-9]\+[[:space:]][^[:space:]]" | grep -e "\.sh" | awk '{print $1}') )
    else
      subProcessIds=()
    fi
    declare -A runningProcessIds
    for subProcessId in "${subProcessIds[@]}"; do
      runningProcessIds["${subProcessId}"]=0
    done
    while [[ "${#runningProcessIds[@]}" -gt 0 ]]; do
      sleep 0.5
      for runningProcessId in "${!runningProcessIds[@]}"; do
        if [[ $(ps -p "${runningProcessId}" | wc -l) -eq 1 ]]; then
          unset runningProcessIds["${runningProcessId}"]
        fi
      done
    done
    # give the output buffer a chance
    sleep 1
    if [[ "${lastExitCode}" -gt 0 ]]; then
      >&2 echo "Finished unexpectedly"
    else
      echo "Finished"
    fi
  fi
}

trap finish EXIT

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} <ACTION>

ACTION:
  construct  Create or update system components
  init       Pull the images required for building
  build      Build the target images and push if required
  rebuild    Re-build the target images and push if required
  errect     Create the containers from source images and run installation process
  source     Create the containers from source images
  install    Run installation process with created containers from source images
  image      Build the image from running containers
  push       Push the built images to remote
  prepare    Pull the images required for running
  run        Create the container from built images and start them
  create     Create the container from built images
  start      Start the containers with created containers from built images
  stop       Stop the constainers
  restart    Re-start the containers
  remove     Remove the constainers
  erase      Stop and remove the containers
  clean      Remove the the built images
  destroy    Remove the built images locally and remotely

  cmd        Execute a command in a container
  bash       Open a bash shell in a container
  config     Show the complete configuration
  names      Show the names of images and containers
  volumes    Show the details of all volumes
  status     Show a current status of images and containers
  list       List all known systems
  reset      Remove all generated data

Example: ${scriptName} build
EOF
}

action="${1}"
if [[ -z "${action}" ]]; then
  >&2 echo "No action defined!"
  usage
  exit 1
fi
export action

if [[ $(which jq | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: jq"
  exit 1
fi

if [[ $(which ts | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: moreutils"
  exit 1
fi

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi

anodosysPath=$(cd -P "$(dirname "${scriptName}")" && pwd)
export anodosysPath

anodosysAppPath="${anodosysPath}/app"
export anodosysAppPath

anodosysUserPath=
source "${anodosysAppPath}/path.sh"
source "${anodosysAppPath}/log.sh"

fileName=
force=0
source "${anodosysAppPath}/prepare-parameters.sh"
export force

source "${anodosysAppPath}/lib.sh"

source "${anodosysAppPath}/construct.sh"

source "${anodosysAppPath}/systems.sh"

source "${anodosysAppPath}/step-scripts.sh"

if [[ -n "${server}" ]]; then
  export server
fi

if [[ -z "${systemName}" ]] && [[ -z "${fileName}" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "config" ]] && [[ -n "${2}" ]]; then
  systemName="${2}"
fi

if [[ -n "${systemName}" ]] && [[ -z "${fileName}" ]] && [[ -f "${anodosysUserPath}/systems.json" ]]; then
  fileName=$(jq -r ". | with_entries(select(.key|match(\"${systemName}\")))[]" "${anodosysUserPath}/systems.json")
fi

if [[ -z "${fileName}" ]]; then
  if [[ ! -f anodosys.json ]] && { test -f anodosys/anodosys.json; test -f anodosys/ads.json; }; then
    cd anodosys
  elif [[ ! -f anodosys.json ]] && { test -f ads/anodosys.json; test -f ads/ads.json; }; then
    cd ads
  fi

  systemPath="${PWD}"
  export systemPath

  if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]]; then
    >&2 echo "Could not find anodosys.json or ads.json in directory: ${PWD}"
    exit 1
  fi

  if [[ -f "anodosys.json" ]]; then
    fileName="anodosys.json"
  else
    fileName="ads.json"
  fi
else
  systemPath=$(dirname "${fileName}")
  export systemPath
fi

if [[ ! -f "${fileName}" ]]; then
  >&2 echo "Could not find configuration at: ${fileName}"
  exit 1
fi

if [[ "${action}" == "reset" ]]; then
  reset=1
else
  reset=0
fi
export reset

anodosysConfigurationFile=
source "${anodosysAppPath}/configuration.sh"

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi
export systemName

if [[ "${action}" != "reset" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "volumes" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "systems" ]]; then
  logName "${systemName}"
fi

setServerConfiguration "${systemName}" "system"

source "${anodosysAppPath}/reset.sh"
source "${anodosysAppPath}/cmd.sh"
source "${anodosysAppPath}/config.sh"
source "${anodosysAppPath}/names.sh"
source "${anodosysAppPath}/volumes.sh"
source "${anodosysAppPath}/status.sh"
source "${anodosysAppPath}/steps.sh"
