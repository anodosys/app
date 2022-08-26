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

if [[ -n "${beforeImageExistsTargetRemoteScript}" ]]; then
  echo "Before image exists target remote script: ${beforeImageExistsTargetRemoteScript}"
  "${beforeImageExistsTargetRemoteScript}"
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No target image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No target image tag for server: ${serverName}"
  exit 1
fi

echo "Checking if remote target image exists: ${imageName}:${imageTag}"
if [[ -z "${repositoryUserName}" ]]; then
  >&2 echo "No repository user name for server: ${serverName}"
  exit 1
elif [[ -z "${repositoryPassword}" ]]; then
  >&2 echo "No repository password for server: ${serverName}"
  exit 1
elif [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}") == 1 ]]; then
  echo "Remote target image exists"
else
  >&2 echo "Remote target image does not exist: ${imageName}:${imageTag}"
  exit 1
fi

if [[ -n "${afterImageExistsTargetRemoteScript}" ]]; then
  echo "After image exists target remote script: ${afterImageExistsTargetRemoteScript}"
  "${afterImageExistsTargetRemoteScript}"
fi
