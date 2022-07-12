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
  -n  Negate the check

Example: ${scriptName} -s
EOF
}

trim()
{
  echo -n "$1" | xargs
}

useSourceImage=0
useTargetImage=0
negate=0

while getopts hstn? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) useSourceImage=1;;
    t) useTargetImage=1;;
    n) negate=1;;
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

echo "- Image exists -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImageExistsScript}" ]]; then
  echo "Before image exists script: ${beforeImageExistsScript}"
  "${beforeImageExistsScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

for serverName in "${serverNames[@]}"; do
  if [[ "${negate}" == 0 ]]; then
    "${currentPath}/../../server/image/exists.sh" -s "${serverName}" -i "${imageSource}"
  else
    "${currentPath}/../../server/image/exists.sh" -s "${serverName}" -i "${imageSource}" -n
  fi
done

if [[ -n "${afterImageExistsScript}" ]]; then
  echo "After image exists script: ${afterImageExistsScript}"
  "${afterImageExistsScript}"
fi
