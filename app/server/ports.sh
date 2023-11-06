#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=

while getopts hs:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -z "${containerPorts}" ]]; then
  containerPorts=()
fi

for containerPort in "${containerPorts[@]}"; do
  printf '%-10s' "${serverName}"
  echo -n " | "

  readarray -d : -t containerPortParts < <(printf '%s' "${containerPort}")
  hostPort="${containerPortParts[0]}"
  containerPort="${containerPortParts[1]}"

  printf '%-14s' "${hostPort}"
  echo -n " | "

  printf '%-14s' "${containerPort}"
  echo ""
done
