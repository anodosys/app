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

logName "${systemName}" "${serverName}"

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerInstallScript}" ]]; then
  echo "Before container install script: ${beforeContainerInstallScript}"
  "${beforeContainerInstallScript}"
fi

containerName="${systemName}_${serverName}"

if [[ -n "${containerInstallScript}" ]]; then
  if [[ -n "${containerInstallParameters}" ]]; then
    containerExecute "${containerName}" "${containerInstallScript}" "${containerInstallParameters[@]}"
  else
    containerExecute "${containerName}" "${containerInstallScript}"
  fi
elif [[ -n "${containerInstall}" ]]; then
  containerCommand "${containerName}" "${containerInstall}"
else
  echo "Nothing to install"
fi

if [[ -n "${afterContainerInstallScript}" ]]; then
  echo "After container install script: ${afterContainerInstallScript}"
  "${afterContainerInstallScript}"
fi
