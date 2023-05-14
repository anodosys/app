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

if [[ -n "${beforeImageExistsSourceRemoteScript}" ]]; then
  echo "Before source image exists remote script: ${beforeImageExistsSourceRemoteScript}"
  "${beforeImageExistsSourceRemoteScript}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No source image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No source image tag for server: ${serverName}"
  exit 1
fi

echo "Checking if remote source image exists: ${imageName}:${imageTag}"
if [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
  echo "Remote source image exists"
elif [[ -z "${repositoryUserName}" ]]; then
  >&2 echo "No repository user name for server: ${serverName}"
  exit 1
elif [[ -z "${repositoryPassword}" ]]; then
  >&2 echo "No repository password for server: ${serverName}"
  exit 1
elif [[ $(imageExistsRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}") == 1 ]]; then
  echo "Remote source image exists"
else
  >&2 echo "Remote source image does not exist: ${imageName}:${imageTag}"
  exit 1
fi

if [[ -n "${afterImageExistsSourceRemoteScript}" ]]; then
  echo "After source image exists remote script: ${afterImageExistsSourceRemoteScript}"
  "${afterImageExistsSourceRemoteScript}"
fi
