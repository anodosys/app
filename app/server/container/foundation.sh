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
  -p  Processed server names

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
processedServerNames=

while getopts hs:p:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    p) processedServerNames=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "system"

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names"
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

readarray -d , -t processedServerNameList < <(printf '%s' "${processedServerNames}")

if [[ -n "${depends}" ]]; then
  for dependServerName in "${depends[@]}"; do
    available=0
    for nextServerName in "${serverNames[@]}"; do
      if [[ "${nextServerName}" == "${dependServerName}" ]]; then
        available=1
      fi
    done
    if [[ "${available}" == 1 ]]; then
      found=0
      for processedServerName in "${processedServerNameList[@]}"; do
        if [[ "${processedServerName}" == "${dependServerName}" ]]; then
          found=1
          break
        fi
      done
      if [[ "${found}" == 0 ]]; then
        echo 0
        exit 0
      fi
    fi
  done
fi

echo 1
