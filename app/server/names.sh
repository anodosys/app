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

printf '%-10s' "${serverName}"
echo -n " | "

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]]; then
  printf '%-65s' "${imageName,,}:${imageTag,,}"
else
  printf '%-65s' ""
fi
echo -n " | "

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName,,}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag,,}"
fi

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]]; then
  printf '%-65s' "${imageName,,}:${imageTag,,}"
else
  printf '%-65s' ""
fi
echo -n " | "

containerName="${systemName}_${serverName}"
printf '%-20s' "${containerName}"

echo ""
