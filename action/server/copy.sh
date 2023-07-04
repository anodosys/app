#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

shift

if [[ -z "${1}" ]]; then
  >&2 echo "No server name specified"
  exit 1
fi

serverName="${1}"
shift

if [[ -n "${1}" ]]; then
  localFileName="${1}"
  shift
  if [[ ! -f "${localFileName}" ]]; then
    >&2 echo "File not found at: ${localFileName}"
    exit 1
  fi
else
  >&2 echo "No file specified"
  exit 1
fi

if [[ -n "${1}" ]]; then
  remoteFileName="${1}"
  shift
fi

if [[ -z "${remoteFileName}" ]]; then
  "${anodosysAppPath}/server/container/copy.sh" \
    -s "${serverName}" \
    -f "${localFileName}"
else
  "${anodosysAppPath}/server/container/copy.sh" \
    -s "${serverName}" \
    -f "${localFileName}" \
    -r "${remoteFileName}"
fi
