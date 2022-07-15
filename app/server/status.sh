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
  -l  Length of server name

Example: ${scriptName} -s web -l 10
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
length=

while getopts hs:l:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    l) length=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

printf "%-${length}s" "${containerName}"

echo -n " | "

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
  echo -n "        X         "
else
  echo -n "                  "
fi

echo -n " | "

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
  echo -n "         X         "
else
  echo -n "                   "
fi

echo -n " | "

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
  echo -n "        X         "
else
  echo -n "                  "
fi

echo -n " | "

if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
  echo -n "         X         "
else
  echo -n "                   "
fi

echo -n " | "

if [[ $(containerExists "${containerName}") == 1 ]]; then
  echo -n "        X        "
else
  echo -n "                 "
fi

echo -n " | "

if [[ $(containerRunning "${containerName}") == 1 ]]; then
  echo -n "        X        "
else
  echo -n "                 "
fi

echo ""
