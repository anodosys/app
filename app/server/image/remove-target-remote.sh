#!/bin/bash -e

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

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

logName "${systemName}" "${serverName}"

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeImageRemoveSourceRemoteScript}" ]]; then
  echo "Before image remove target remote script: ${beforeImageRemoveSourceRemoteScript}"
  "${beforeImageRemoveSourceRemoteScript}"
fi

if [[ -z "${buildImageName}" ]] && [[ -z "${buildImageTag}" ]]; then
  echo "No removing of remote image required"
  exit 0
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName,,}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag,,}"
fi

if [[ -z "${repositoryUserName}" ]] && [[ -z "${repositoryPassword}" ]] && [[ -z "${targetRepositoryUserName}" ]] && [[ -z "${targetRepositoryPassword}" ]]; then
  imageRemoveRemote "${imageName,,}" "${imageTag,,}"
else
  if [[ -z "${repositoryUserName}" ]] && [[ -z "${targetRepositoryUserName}" ]]; then
    >&2 echo "No repository user name to remove target image for server: ${serverName}"
    exit 1
  elif [[ -z "${repositoryPassword}" ]]&& [[ -z "${targetRepositoryPassword}" ]]; then
    >&2 echo "No repository password to remove target image for server: ${serverName}"
    exit 1
  elif [[ -n "${targetRepositoryUserName}" ]]; then
    imageRemoveRemote "${imageName,,}" "${imageTag,,}" "${targetRepositoryUserName}" "${targetRepositoryPassword}"
  else
    imageRemoveRemote "${imageName,,}" "${imageTag,,}" "${repositoryUserName}" "${repositoryPassword}"
  fi
fi

if [[ -n "${afterImageRemoveSourceRemoteScript}" ]]; then
  echo "After image remove target remote script: ${afterImageRemoveSourceRemoteScript}"
  "${afterImageRemoveSourceRemoteScript}"
fi
