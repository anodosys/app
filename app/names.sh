#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

if [[ -z "${action}" ]]; then
  >&2 echo "No action defined"
  exit 1
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names defined!"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined"
  exit 1
fi

if [[ "${action}" == "names" ]]; then
  echo "server     | source image                                                      | target image                                                      | container"
  echo "---------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- | -------------------------"
  for serverName in "${serverNames[@]}"; do
    "${anodosysAppPath}/server/names.sh" -s "${serverName}"
  done
  exit 0
fi
