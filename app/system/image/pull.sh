#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Use source image
  -t  Use target image

Example: ${scriptName} -s
EOF
}

trim()
{
  echo -n "$1" | xargs
}

useSourceImage=0
useTargetImage=0

while getopts hst? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) useSourceImage=1;;
    t) useTargetImage=1;;
    ?) usage; exit 1;;
  esac
done

if [[ "${useSourceImage}" == 0 ]] && [[ "${useTargetImage}" == 0 ]]; then
  >&2 echo "Please specifiy which image to use"
  usage
  exit 1
fi

if [[ "${useSourceImage}" == 1 ]]; then
  imageSource="source"
else
  imageSource="target"
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image pull -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImagePullScript}" ]]; then
  echo "Before image pull script: ${beforeImagePullScript}"
  "${beforeImagePullScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

declare -A processIds
for serverName in "${serverNames[@]}"; do
  imageScript="${PWD}/${serverName}/image/pull.sh"
  if [[ -f "${imageScript}" ]]; then
    echo "[${serverName}] Pulling image of server: ${serverName} with custom script: ${imageScript}"
    "${imageScript}" &
  else
    "${currentPath}/../../server/image/pull.sh" -s "${serverName}" -i "${imageSource}" &
  fi
  processIds["${serverName}"]=$!
done

for serverName in "${!processIds[@]}"; do
  processId="${processIds[${serverName}]}"
  wait "${processId}"
done

if [[ -n "${afterImagePullScript}" ]]; then
  echo "After image pull script: ${afterImagePullScript}"
  "${afterImagePullScript}"
fi
