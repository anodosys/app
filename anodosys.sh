#!/bin/bash -e

prepareValue()
{
  local text="$*"

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  text=$(printf '%s' "${text}")
  text="${text%\"}"
  text="${text#\"}"
  echo -n "${text}"
}

# shellcheck disable=SC2034
typeset -fx prepareValue

finish()
{
  local lastExitCode
  local processId
  local sessionId
  local subProcessIds
  local subProcessId
  local runningProcessIds
  local runningProcessId

  if [[ "${action}" != "" ]] && [[ "${action}" != "steps" ]] && [[ "${action}" != "construct" ]] && [[ "${action}" != "list" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "cmdi" ]] && [[ "${action}" != "cmdiq" ]] && [[ "${action}" != "cmdq" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "copy" ]] && [[ "${action}" != "exec" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "reset" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "volumes" ]]; then
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
  else
    if [[ "${action}" == "steps" ]]; then
      sleep 1
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
  list       List all known systems

  construct  Create or update system components
  reset      Remove all generated data of the system

  init       Pull the images required for building
  build      Build the target images and push if required
  rebuild    Re-build the target images and push if required
  rise       Create the containers from source images and run installation process
  source     Create the containers from source images
  install    Run installation process with created containers from source images
  image      Build the image from running containers
  push       Push the built images to remote
  prepare    Pull the images required for running
  run        Create the container from built images and start them
  create     Create the container from built images
  start      Start the containers with created containers from built images
  stop       Stop the containers
  restart    Re-start the containers
  remove     Remove the containers
  clean      Remove the the built images
  purge      Stop and remove the containers
  erase      Stop and remove the containers and remove the build images
  destroy    Remove the built images locally and remotely

  config     Show the complete configuration of the system
  names      Show the names of images and containers of the system
  status     Show a current status of images and containers of the system
  volumes    Show the details of all volumes
  ports      Show the details of all ports

  bash       Open a bash shell in a container
  cmd        Execute a command in a container
  cmdi       Execute a command in a container in interactive mode
  cmdiq      Execute a command in a container in interactive mode and without any messages
  cmdq       Execute a command in a container without any messages
  copy       Copy a local file into a container
  exec       Copy and execute a local script in a container

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

anodosysExtensionPath=
anodosysExtensions=
anodosysActionSystemPath=
anodosysActionServerPath=
anodosysUserPath=
anodosysUserExtensionPath=
anodosysUserExtensions=
anodosysUserActionSystemPath=
anodosysUserActionServerPath=
source "${anodosysAppPath}/path.sh"
source "${anodosysAppPath}/log.sh"

fileName=
force=0
local=0
source "${anodosysAppPath}/prepare-parameters.sh"
export force
export local

source "${anodosysAppPath}/lib.sh"

for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
  if [[ -f "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/system/${action}.sh" ]]; then
    source "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/system/${action}.sh"
    exit 0
  fi
done

for anodosysExtension in "${anodosysExtensions[@]}"; do
  if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/action/system/${action}.sh" ]]; then
    source "${anodosysExtensionPath}/${anodosysExtension}/action/system/${action}.sh"
    exit 0
  fi
done

if [[ -f "${anodosysUserActionSystemPath}/${action}.sh" ]]; then
  source "${anodosysUserActionSystemPath}/${action}.sh"
  exit 0
fi

if [[ -f "${anodosysActionSystemPath}/${action}.sh" ]]; then
  source "${anodosysActionSystemPath}/${action}.sh"
  exit 0
fi

source "${anodosysAppPath}/step-scripts.sh"

if [[ -n "${server}" ]]; then
  export server
fi

if [[ -z "${systemName}" ]] && [[ -z "${fileName}" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "cmdi" ]] && [[ "${action}" != "cmdiq" ]] && [[ "${action}" != "cmdq" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "copy" ]] && [[ "${action}" != "exec" ]] && [[ -n "${2}" ]]; then
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

systemActionPath="${systemPath}/action"

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

if [[ "${action}" != "construct" ]] && [[ "${action}" != "list" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "cmdi" ]] && [[ "${action}" != "cmdiq" ]] && [[ "${action}" != "cmdq" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "copy" ]] && [[ "${action}" != "exec" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "reset" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "volumes" ]]; then
  logName "${systemName}"
fi

setServerConfiguration "${systemName}" "system"

if [[ -f "${systemActionPath}/${action}.sh" ]]; then
  source "${systemActionPath}/${action}.sh"
  exit 0
fi

for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
  if [[ -f "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/${action}.sh" ]]; then
    trap - EXIT
    source "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/${action}.sh"
    exit 0
  fi
done

for anodosysExtension in "${anodosysExtensions[@]}"; do
  if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/action/server/${action}.sh" ]]; then
    trap - EXIT
    source "${anodosysExtensionPath}/${anodosysExtension}/action/server/${action}.sh"
    exit 0
  fi
done

if [[ -f "${anodosysUserActionServerPath}/${action}.sh" ]]; then
  trap - EXIT
  source "${anodosysUserActionServerPath}/${action}.sh"
  exit 0
fi

if [[ -f "${anodosysActionServerPath}/${action}.sh" ]]; then
  source "${anodosysActionServerPath}/${action}.sh"
  exit 0
fi

source "${anodosysAppPath}/steps.sh"
