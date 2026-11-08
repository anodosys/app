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
  # must be captured first, any later command overwrites it
  local lastExitCode=$?
  local processId
  local sessionId
  local subProcessIds
  local subProcessId
  local runningProcessIds
  local runningProcessId
  local ancestorProcessIds
  local ancestorProcessId

  if [[ "${action}" != "" ]] && [[ "${action}" != "steps" ]] && [[ "${action}" != "construct" ]] && [[ "${action}" != "list" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "cmdi" ]] && [[ "${action}" != "cmdiq" ]] && [[ "${action}" != "cmdq" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "copy" ]] && [[ "${action}" != "exec" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "ports" ]] && [[ "${action}" != "reset" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "step" ]] && [[ "${action}" != "volumes" ]] && [[ "${action}" != "extension" ]] && [[ "${action}" != "log" ]]; then
    processId=$$
    sessionId=$(ps -o sid= -p ${processId})
    sessionId=$(prepareValue "${sessionId}")
    if [[ -n "${sessionId}" ]]; then
      subProcessIds=( $(ps --forest -o pid,cmd -g "${sessionId}" | tail -n +2 | grep -e "[[:space:]]*[0-9]\+[[:space:]][^[:space:]]" | grep -e "\.sh" | awk '{print $1}') )
    else
      subProcessIds=()
    fi
    # never wait for this process or its ancestors (for example a wrapper shell whose command line contains ".sh"),
    # they cannot finish before this process does
    declare -A ancestorProcessIds
    ancestorProcessId="${processId}"
    while [[ -n "${ancestorProcessId}" ]] && [[ "${ancestorProcessId}" -gt 0 ]]; do
      ancestorProcessIds["${ancestorProcessId}"]=1
      ancestorProcessId=$(ps -o ppid= -p "${ancestorProcessId}" 2>/dev/null || true)
      ancestorProcessId=$(prepareValue "${ancestorProcessId}")
    done
    declare -A runningProcessIds
    for subProcessId in "${subProcessIds[@]}"; do
      if [[ -z "${ancestorProcessIds[${subProcessId}]+x}" ]]; then
        runningProcessIds["${subProcessId}"]=0
      fi
    done
    while [[ "${#runningProcessIds[@]}" -gt 0 ]]; do
      sleep 0.5
      for runningProcessId in "${!runningProcessIds[@]}"; do
        if [[ $(ps -p "${runningProcessId}" | wc -l) -eq 1 ]]; then
          unset 'runningProcessIds[${runningProcessId}]'
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
# the original command line, written into the log file of the system
anodosysCommandLine="${scriptName} $*"

# shows the logo on stderr above usage and error messages, when it goes to a terminal and was not shown yet
showBanner()
{
  if [[ -t 2 ]] && [[ -z "${anodosysBannerShown}" ]]; then
    source "${anodosysPath}/banner.sh" >&2
    anodosysBannerShown=1
  fi
}

usage()
{
  local extensionName="${1}"

  showBanner
  cat >&2 << EOF

usage: ads <ACTION>

ACTION:
EOF

  if [[ -z "${extensionName}" ]]; then
cat >&2 << EOF

  list                          List all known systems
  extension                     Add, update, reset or remove extensions
  update                        Update Anodosys to the latest or a given release (--applicationVersion)
  version                       Show the installed version

  construct                     Create or update system components
  reset                         Remove all generated data of the system

  host                          Check host requirements
  init                          Pull the images required for building
  build                         Build the target images and push if required
  rebuild                       Re-build the target images and push if required
  shell                         Re-build the target images
  rise                          Create the containers from source images and run installation process
  source                        Create the containers from source images
  install                       Run installation process with created containers from source images
  image                         Build the image from running containers
  push                          Push the built images to remote
  prepare                       Pull the built images required for running
  run                           Create the container from built images and start them
  create                        Create the container from built images
  start                         Start the containers with created containers from built images
  stop                          Stop the containers
  restart                       Re-start the containers
  teardown                      Teardown the containers
  remove                        Remove the containers
  clean                         Remove the the built images
  purge                         Stop and remove the containers
  erase                         Stop and remove the containers and remove the build images
  destroy                       Remove the built images locally and remotely

  config                        Show the complete configuration of the system
  names                         Show the names of images and containers of the system
  status                        Show a current status of images and containers of the system
  volumes                       Show the details of all volumes
  paths                         Show the details of all paths
  ports                         Show the details of all ports
  log                           Show the log of the system (--lines <number>, --follow)

  bash                          Open a bash shell in a container
  cmd                           Execute a command in a container
  cmdi                          Execute a command in a container in interactive mode
  cmdiq                         Execute a command in a container in interactive mode and without any messages
  cmdq                          Execute a command in a container without any messages
  copy                          Copy a local file into a container
  exec                          Copy and execute a local script in a container
EOF
  fi

  if [[ -z "${extensionName}" ]] && [[ -n "${systemActionPath}" ]] && [[ -d "${systemActionPath}" ]]; then
    systemActions=( $(find "${systemActionPath}/" -name "*.sh" -exec basename {} .sh \; | sort -n) )
    if [[ -n "${systemActions[*]}" ]]; then
      >&2 echo ""
      for systemAction in "${systemActions[@]}"; do
        systemActionDescription=
        if [[ -f "${systemActionPath}/${systemAction}.txt" ]]; then
          systemActionDescription=$(cat "${systemActionPath}/${systemAction}.txt")
        fi
        >&2 echo "  $(printf '%-30s' "${systemAction}")${systemActionDescription}"
      done
    fi
  fi

  for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
    if [[ -z "${extensionName}" ]] || { [[ -n "${extensionName}" ]] && [[ "${extensionName}" == "${anodosysUserExtension}" ]]; }; then
      if [[ -d "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/" ]]; then
        userExtensionActions=( $(find "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/" -name "*.sh" -exec basename {} .sh \; | sort -n) )
      else
        userExtensionActions=()
      fi
      if [[ -n "${userExtensionActions[*]}" ]]; then
        >&2 echo ""
        for userExtensionAction in "${userExtensionActions[@]}"; do
          userExtensionActionDescription=
          if [[ -f "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/${userExtensionAction}.txt" ]]; then
            userExtensionActionDescription=$(cat "${anodosysUserExtensionPath}/${anodosysUserExtension}/action/server/${userExtensionAction}.txt")
          fi
          >&2 echo "  $(printf '%-30s' "${anodosysUserExtension}:${userExtensionAction}")${userExtensionActionDescription}"
        done
      fi
    fi
  done

  for anodosysExtension in "${anodosysExtensions[@]}"; do
    if [[ -z "${extensionName}" ]] || { [[ -n "${extensionName}" ]] && [[ "${extensionName}" == "${anodosysExtension}" ]]; }; then
      if [[ -d "${anodosysExtensionPath}/${anodosysExtension}/action/server/" ]]; then
        extensionActions=( $(find "${anodosysExtensionPath}/${anodosysExtension}/action/server/" -name "*.sh" -exec basename {} .sh \; | sort -n) )
      else
        extensionActions=()
      fi
      if [[ -n "${extensionActions[*]}" ]]; then
        >&2 echo ""
        for extensionAction in "${extensionActions[@]}"; do
          extensionActionDescription=
          if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/action/server/${extensionAction}.txt" ]]; then
            extensionActionDescription=$(cat "${anodosysExtensionPath}/${anodosysExtension}/action/server/${extensionAction}.txt")
          fi
          >&2 echo "  $(printf '%-20s' "${extensionAction}")${extensionActionDescription}"
        done
      fi
    fi
  done

  cat >&2 << EOF

Example: ads build

EOF
}

if ! command -v jcp >/dev/null 2>&1; then
  >&2 echo "Please install required package: jcp"
  exit 1
fi

if ! command -v j2v >/dev/null 2>&1; then
  >&2 echo "Please install required package: j2v"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  >&2 echo "Please install required package: jq"
  exit 1
fi

if ! command -v ts >/dev/null 2>&1; then
  >&2 echo "Please install required package: moreutils"
  exit 1
fi

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi

if [[ -z "${GID}" ]]; then
  GID=$(id -g)
  export GID
fi

anodosysPath=$(cd -P "$(dirname "${scriptName}")" && pwd)
export anodosysPath

# extensions are managed independently of any system configuration
if [[ "${1}" == "extension" ]]; then
  shift
  exec "${anodosysPath}/extension.sh" "$@"
fi

if [[ "${1}" == "update" ]]; then
  shift
  exec "${anodosysPath}/update.sh" "$@"
fi

if [[ "${1}" == "version" ]]; then
  if [[ -L "$(dirname "${anodosysPath}")/current" ]]; then
    basename "${anodosysPath}"
  elif [[ -d "${anodosysPath}/.git" ]]; then
    git -C "${anodosysPath}" describe --tags --always --dirty
  else
    echo "unknown"
  fi
  exit 0
fi

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

# listing systems does not depend on any system configuration
if [[ "${1}" == "list" ]]; then
  source "${anodosysActionSystemPath}/list.sh"
  exit 0
fi

fileName=
force=0
localImages=0
declare -A prepareParameters=()
source "${anodosysAppPath}/prepare-parameters.sh"
# the --local flag is stored as localImages to avoid a variable named like the builtin
if test "${prepareParameters["local"]+isset}"; then
  localImages="${prepareParameters["local"]}"
  unset local
fi
export force
export localImages
export env

source "${anodosysAppPath}/lib.sh"

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
  if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]] && { test -f anodosys/anodosys.json; test -f anodosys/ads.json; }; then
    cd anodosys
  elif [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]] && { test -f ads/anodosys.json; test -f ads/ads.json; }; then
    cd ads
  elif [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]] && { test -f ../anodosys.json; test -f ../ads.json; }; then
    cd ..
  elif [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]] && { test -f ../ads/anodosys.json; test -f ../ads/ads.json; }; then
    cd ../ads
  fi

  systemPath="${PWD}"
  export systemPath

  if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]]; then
    showBanner
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
  showBanner
  >&2 echo "Could not find configuration at: ${fileName}"
  exit 1
fi

action="${1}"
if [[ -z "${action}" ]]; then
  >&2 echo "No action defined!"
  usage
  exit 1
fi
export action

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

if [[ "${action}" != "construct" ]] && [[ "${action}" != "list" ]] && [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "cmdi" ]] && [[ "${action}" != "cmdiq" ]] && [[ "${action}" != "cmdq" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "copy" ]] && [[ "${action}" != "exec" ]] && [[ "${action}" != "names" ]] && [[ "${action}" != "ports" ]] && [[ "${action}" != "reset" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "step" ]] && [[ "${action}" != "volumes" ]] && [[ "${action}" != "log" ]]; then
  # Show the logo once per top-level run in a terminal, before the output is passed to the log file, and not for ads
  # calls made by scripts
  if [[ -t 1 ]] && [[ -z "${anodosysBannerShown}" ]]; then
    source "${anodosysPath}/banner.sh"
    export anodosysBannerShown=1
  fi
  logStart "${systemName}" "${anodosysCommandLine}"
  logName "${systemName}"
fi

setServerConfiguration "${systemName}" "system"

readarray -d : -t actionParts < <(printf '%s' "${action}")

if test "${actionParts[1]+isset}"; then
  actionExtension="${actionParts[0]}"
  action="${actionParts[1]}"

  for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
    if [[ "${anodosysUserExtension}" == "${actionExtension}" ]] && [[ -f "${anodosysUserExtensionPath}/${actionExtension}/action/server/${action}.sh" ]]; then
      trap - EXIT
      source "${anodosysUserExtensionPath}/${actionExtension}/action/server/${action}.sh"
      exit 0
    fi
  done

  for anodosysExtension in "${anodosysExtensions[@]}"; do
    if [[ "${anodosysExtension}" == "${actionExtension}" ]] && [[ -f "${anodosysExtensionPath}/${actionExtension}/action/server/${action}.sh" ]]; then
      trap - EXIT
      source "${anodosysExtensionPath}/${actionExtension}/action/server/${action}.sh"
      exit 0
    fi
  done
fi

if [[ -f "${systemActionPath}/${action}.sh" ]]; then
  trap - EXIT
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
  trap - EXIT
  source "${anodosysActionServerPath}/${action}.sh"
  exit 0
fi

for anodosysUserExtension in "${anodosysUserExtensions[@]}"; do
  if [[ "${action}" == "${anodosysUserExtension}" ]]; then
    logDisable
    action="extension"
    usage "${anodosysUserExtension}"
    exit 1
  fi
done

for anodosysExtension in "${anodosysExtensions[@]}"; do
  if [[ "${action}" == "${anodosysExtension}" ]]; then
    logDisable
    action="extension"
    usage "${anodosysExtension}"
    exit 1
  fi
done

source "${anodosysAppPath}/steps.sh"
