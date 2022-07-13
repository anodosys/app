#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name
  -i  Image source (source or target)
  -n  Negate the check
  -l  Check only local

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
imageSource=
negate=0
local=0

while getopts hs:i:nl? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    i) imageSource=$(trim "$OPTARG");;
    n) negate=1;;
    l) local=1;;
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

if [[ -n "${beforeImageExistsScript}" ]]; then
  echo "Before image exists script: ${beforeImageExistsScript}"
  "${beforeImageExistsScript}"
fi

containerName="${systemName}_${serverName}"

if [[ $(containerExists "${containerName}") == 1 ]]; then
  echo "No need to check image"
  exit 0
fi

if [[ "${imageSource}" == "source" ]]; then
  if [[ -z "${imageName}" ]]; then
    >&2 echo "No image name for server: ${serverName}"
    exit 1
  fi

  if [[ -z "${imageTag}" ]]; then
    >&2 echo "No image tag for server: ${serverName}"
    exit 1
  fi

  echo "Checking if image exists: ${imageName}:${imageTag}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Local image exists: ${imageName}:${imageTag}"
    if [[ "${negate}" == 0 ]]; then
      exit 1
    fi
  elif [[ ${local} == 0 ]] && [[ $(imageExistsRemote "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Remote image exists: ${imageName}:${imageTag}"
    if [[ "${negate}" == 0 ]]; then
      exit 1
    fi
  elif [[ "${negate}" == 1 ]]; then
    echo "Image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
else
  if [[ -n "${buildImageName}" ]] || [[ -n "${buildImageTag}" ]]; then
    echo "Checking if image exists: ${buildImageName}:${buildImageTag}"
    if [[ $(imageExists "${buildImageName}" "${buildImageTag}") == 1 ]]; then
      echo "Local image exists: ${buildImageName}:${buildImageTag}"
      if [[ "${negate}" == 0 ]]; then
        exit 1
      fi
    elif [[ ${local} == 0 ]] && [[ $(imageExistsRemote "${buildImageName}" "${buildImageTag}") == 1 ]]; then
      echo "Remote image exists: ${buildImageName}:${buildImageTag}"
      if [[ "${negate}" == 0 ]]; then
        exit 1
      fi
    elif [[ "${negate}" == 1 ]]; then
      >&2 echo "Image does not exist: ${buildImageName}:${buildImageTag}"
      exit 1
    fi
  else
    echo "No checking required"
  fi
fi

if [[ -n "${afterImageExistsScript}" ]]; then
  echo "After image exists script: ${afterImageExistsScript}"
  "${afterImageExistsScript}"
fi
