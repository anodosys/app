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
  -p  Supports server names
  -r  Running server names

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
supportServerNames=
runningServerNames=

while getopts hs:p:r:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    p) supportServerNames=$(trim "$OPTARG");;
    r) runningServerNames=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ "${supportServerNames}" != "none" ]]; then
  readarray -d , -t supportServerNameList < <(printf '%s' "${supportServerNames}")
else
  supportServerNameList=()
fi

if [[ "${runningServerNames}" != "none" ]]; then
  readarray -d , -t runningServerNameList < <(printf '%s' "${runningServerNames}")
else
  runningServerNameList=()
fi

for supportServerName in "${supportServerNameList[@]}"; do
  found=0
  for runningServerName in "${runningServerNameList[@]}"; do
    if [[ "${supportServerName}" == "${runningServerName}" ]]; then
      found=1
      break
    fi
  done
  if [[ "${found}" == 1 ]]; then
    echo 0
    exit 0
  fi
done

echo 1
