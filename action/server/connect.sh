#!/bin/bash -e

# ads connect <container> [--disconnect]
#
# Connects a container that is not part of the system, for example a database tool, to the network of the system. It
# then reaches the servers by their names and container ports, for example database:3306, without host ports.

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined"
  exit 1
fi

connectContainer="${2}"

if [[ -z "${connectContainer}" ]]; then
  >&2 echo "No container specified, usage: ads connect <container> [--disconnect]"
  exit 1
fi

if [[ $(docker container inspect "${connectContainer}" >/dev/null 2>&1 && echo 1 || echo 0) == 0 ]]; then
  >&2 echo "Container does not exist: ${connectContainer}"
  exit 1
fi

if [[ $(docker network inspect "${systemName}" >/dev/null 2>&1 && echo 1 || echo 0) == 0 ]]; then
  >&2 echo "Network of system: ${systemName} does not exist, start the system first"
  exit 1
fi

connected=$(docker inspect -f "{{ json .NetworkSettings.Networks }}" "${connectContainer}" | jq -r --arg network "${systemName}" 'has($network)')

# set by the --disconnect parameter
# shellcheck disable=SC2154
if [[ "${disconnect}" == 1 ]]; then
  if [[ "${connected}" == "true" ]]; then
    docker network disconnect "${systemName}" "${connectContainer}"
    echo "Disconnected container: ${connectContainer} from network: ${systemName}" | sed $'s,.*,\e[0;32m&\e[m,'
  else
    echo "Container: ${connectContainer} is not connected to network: ${systemName}"
  fi
elif [[ "${connected}" == "true" ]]; then
  echo "Container: ${connectContainer} is already connected to network: ${systemName}"
else
  docker network connect "${systemName}" "${connectContainer}"
  echo "Connected container: ${connectContainer} to network: ${systemName}" | sed $'s,.*,\e[0;32m&\e[m,'
  echo "The servers are reachable by their names, for example: $(IFS=,; echo "${serverNames[*]}" | sed 's/,/, /g')"
fi
