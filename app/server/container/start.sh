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

containerName="${systemName}_${serverName}"

if [[ -z "${useNamedVolumes}" ]]; then
  useNamedVolumes="false"
fi

if [[ -n "${beforeContainerStartScript}" ]]; then
  echo "Before container start script: ${beforeContainerStartScript}"
  if [[ -n "${beforeContainerStartParameters}" ]]; then
    "${beforeContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerStartParameters[@]}"
  else
    "${beforeContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${imageInteractiveRun}" ]] && [[ "${imageInteractiveRun}" == "true" ]]; then
  if [[ $(containerExists "${containerName}") == 0 ]]; then
    echo "Image requires interactive run"

    if [[ -z "${imageName}" ]]; then
      >&2 echo "No source image name for server: ${serverName}"
      exit 1
    fi
    if [[ -z "${imageTag}" ]]; then
      >&2 echo "No source image tag for server: ${serverName}"
      exit 1
    fi

    if [[ -n "${imageInteractiveCommand}" ]]; then
      containerRun "${imageName}:${imageTag}" "${containerName}" "${imageInteractiveCommand}"
    else
      containerRun "${imageName}:${imageTag}" "${containerName}"
    fi

    exit 0
  fi
fi

if [[ -z "${skipPortsAvailable}" ]]; then
  skipPortsAvailable="false"
fi

if [[ -z "${follow}" ]]; then
  follow="false"
fi

containerStart "${containerName}" "${useNamedVolumes}" no "${skipPortsAvailable}" "${follow}"

if [[ -n "${afterContainerStartScript}" ]]; then
  echo "After container start script: ${afterContainerStartScript}"
  if [[ -n "${afterContainerStartParameters}" ]]; then
    "${afterContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerStartParameters[@]}"
  else
    "${afterContainerStartScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi
