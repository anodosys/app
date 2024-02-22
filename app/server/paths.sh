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

if [[ -z "${containerPaths}" ]]; then
  containerPaths=()
fi

for containerPath in "${containerPaths[@]}"; do
  printf '%-10s' "${serverName}"
  echo -n " | "

  readarray -d : -t containerPathParts < <(printf '%s' "${containerPath}")
  targetPath="${containerPathParts[0]}"
  if [[ -d "${targetPath}" ]]; then
    targetPath=$(realpath "${targetPath}")
  fi
  if test "${containerPathParts[1]+isset}"; then
    targetUser="${containerPathParts[1]}"
    if [[ -z "${targetUser}" ]]; then
      targetUser="me"
    fi
  else
    targetUser="me"
  fi
  if test "${containerPathParts[2]+isset}"; then
    mode="${containerPathParts[2]}"
    if [[ -z "${mode}" ]]; then
      mode="r"
    fi
  else
    mode="r"
  fi

  printf '%-70s' "${targetPath}"
  echo -n " | "

  printf '%-15s' "${targetUser}"
  echo -n " | "

  printf '%-4s' "${mode}"
  echo ""
done
