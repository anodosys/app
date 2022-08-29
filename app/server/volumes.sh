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

if [[ -z "${containerVolumes}" ]]; then
  containerVolumes=()
fi

for containerVolume in "${containerVolumes[@]}"; do
  printf '%-10s' "${serverName}"
  echo -n " | "

  readarray -d : -t containerVolumeParts < <(printf '%s' "${containerVolume}")
  sourcePath="${containerVolumeParts[0]}"
  if [[ -d "${sourcePath}" ]]; then
    sourcePath=$(realpath "${sourcePath}")
  fi
  targetPath="${containerVolumeParts[1]}"
  if test "${containerVolumeParts[2]+isset}"; then
    targetUser="${containerVolumeParts[2]}"
    if [[ -z "${targetUser}" ]]; then
      targetUser="local"
    fi
  else
    targetUser="local"
  fi
  if test "${containerVolumeParts[3]+isset}"; then
    mode="${containerVolumeParts[3]}"
    if [[ -z "${mode}" ]]; then
      mode="r"
    fi
  else
    mode="r"
  fi

  printf '%-90s' "${sourcePath}"
  echo -n " | "

  printf '%-50s' "${targetPath}"
  echo -n " | "

  printf '%-15s' "${targetUser}"
  echo -n " | "

  printf '%-5s' "${mode}"
  echo ""
done
