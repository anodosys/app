#!/bin/bash -e

finish()
{
  if [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "status" ]]; then
    # give the output buffer a chance
    sleep 1
    echo "Finished"
  fi
}

trap finish EXIT

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} <ACTION>

ACTION:
  build     Build the target images and push if required
  rebuild   Re-build the target images and push if required
  pull      Pull the images required for building and starting
  install   Build the containers, but do not create images
  image     Build the image from running containers
  push      Push the build images to remote
  clean     Remove the containers and the build images
  destroy   Clean and remove the build images pushed to remote
  create    Create the container from build images
  start     Start the containers
  restart   Re-start the containers
  stop      Stop the constainers
  remove    Remove the constainers
  cmd       Execute a command in a container
  config    Show the complete configuration
  status    Show an overview of images and containers

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

source "${anodosysAppPath}/path.sh"
source "${anodosysAppPath}/log.sh"

fileName=
source "${anodosysAppPath}/prepare-parameters.sh"

if [[ -n "${server}" ]]; then
  export server
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

source "${anodosysAppPath}/lib.sh"

anodosysConfigurationFile=
source "${anodosysAppPath}/configuration.sh"

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi
export systemName

if [[ "${action}" != "bash" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]] && [[ "${action}" != "status" ]] && [[ "${action}" != "systems" ]]; then
  logName "${systemName}"
fi

setServerConfiguration "${systemName}" "system"

source "${anodosysAppPath}/cmd.sh"
source "${anodosysAppPath}/config.sh"
source "${anodosysAppPath}/status.sh"
source "${anodosysAppPath}/steps.sh"
