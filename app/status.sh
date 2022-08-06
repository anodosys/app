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

if [[ "${action}" == "status" ]]; then
  mode="${2:-local}"
  maxLength=9
  for serverName in "${serverNames[@]}"; do
    length=$(("${#systemName}" + "${#serverName}" + 1))
    if [[ "${length}" -gt "${maxLength}" ]]; then
      maxLength="${length}"
    fi
  done
  printf "%-${maxLength}s" "Container"
  if [[ "${mode}" == "all" ]]; then
    echo " | local source image | remote source image | local target image | remote target image | container created | container running"
    printf "%${maxLength}s" "" |tr " " "-"
    echo " | ------------------ | ------------------- | ------------------ | ------------------- | ----------------- | -----------------"
  elif [[ "${mode}" == "local" ]]; then
    echo " | local source image | local target image | container created | container running"
    printf "%${maxLength}s" "" |tr " " "-"
    echo " | ------------------ | ------------------ | ----------------- | -----------------"
  fi
  for serverName in "${serverNames[@]}"; do
    "${anodosysAppPath}/server/status.sh" -s "${serverName}" -l "${maxLength}" -m "${mode}"
  done
  exit 0
fi
