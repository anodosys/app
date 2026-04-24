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

if [[ -z "${skipImageCheck}" ]]; then
  if [[ -n "${local}" ]] && [[ "${local}" == 1 ]]; then
    skipImageCheck="true"
  else
    skipImageCheck="false"
  fi
fi

if [[ -n "${beforeImagePullTargetScript}" ]]; then
  echo "Before image pull target script: ${beforeImagePullTargetScript}"
  "${beforeImagePullTargetScript}"
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag,,}"
fi

if [[ -z "${imageName}" ]]; then
  >&2 echo "No target image name for server: ${serverName}"
  exit 1
fi

if [[ -z "${imageTag}" ]]; then
  >&2 echo "No target image tag for server: ${serverName}"
  exit 1
fi

if [[ $(imageExists "${imageName,,}" "${imageTag,,}") == 0 ]]; then
  if [[ $(imageExistsRemote "${imageName,,}" "${imageTag,,}") == 2 ]]; then
    imagePull "${imageName,,}" "${imageTag,,}"
  elif [[ -z "${repositoryUserName}" ]]; then
    >&2 echo "No repository user name to pull target for server: ${serverName}"
    exit 1
  elif [[ -z "${repositoryPassword}" ]]; then
    >&2 echo "No repository password to pull target for server: ${serverName}"
    exit 1
  elif [[ $(imageExistsRemote "${imageName,,}" "${imageTag,,}" "${repositoryUserName}" "${repositoryPassword}") != 0 ]]; then
    imagePull "${imageName,,}" "${imageTag,,}"
  else
    >&2 echo "Target image does not exist: ${imageName,,}:${imageTag,,}"
    exit 1
  fi
else
  if [[ "${skipImageCheck}" == "true" ]]; then
    echo "Skipping target image check for server: ${serverName}"
  else
    imageCheckRemoteResult=$(imageCheckRemote "${imageName,,}" "${imageTag,,}")
    if [[ "${imageCheckRemoteResult}" == 2 ]]; then
      imagePull "${imageName,,}" "${imageTag,,}" yes
    elif [[ "${imageCheckRemoteResult}" == 0 ]]; then
      if [[ -z "${repositoryUserName}" ]]; then
        >&2 echo "No repository user name to pull target image for server: ${serverName}"
        exit 1
      elif [[ -z "${repositoryPassword}" ]]; then
        >&2 echo "No repository password to pull target image for server: ${serverName}"
        exit 1
      elif [[ $(imageCheckRemote "${imageName,,}" "${imageTag,,}" "${repositoryUserName}" "${repositoryPassword}") == 2 ]]; then
        imagePull "${imageName,,}" "${imageTag,,}" yes
      else
        echo "No need to pull target image: ${imageName,,}:${imageTag,,}"
      fi
    else
      echo "No need to pull target image: ${imageName,,}:${imageTag,,}"
    fi
  fi
fi

if [[ -n "${afterImagePullTargetScript}" ]]; then
  echo "After image pull target script: ${afterImagePullTargetScript}"
  "${afterImagePullTargetScript}"
fi
