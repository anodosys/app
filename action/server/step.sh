#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

# shellcheck disable=SC2154
if [[ "${#stepScripts[@]}" -eq 0 ]]; then
  >&2 echo "No step scripts defined"
  exit 1
fi

shift

if [[ -z "${1}" ]]; then
  >&2 echo "No step name defined!"
  echo ""

  echo "Available steps:"
  stepNames=($(printf '%s\n' "${!stepScripts[@]}" | sort -n))
  for stepName in "${stepNames[@]}"
  do
    echo "  ${stepName}"
  done
  exit 1
fi

stepName="${1}"
shift

if [[ -n "${1}" ]]; then
  server="${1}"
  export server
  shift
fi

if test "${stepScripts["${stepName}"]+isset}"; then
  stepScript="${stepScripts["${stepName}"]}"
  if [[ -f "${stepScript}" ]]; then
    "${stepScript}"
  else
    >&2 echo "Step script not found at: ${stepScript}"
    exit 1
  fi
else
  >&2 echo "No script found to execute step: ${stepName}"
  echo ""

  echo "Available steps:"
  stepNames=($(printf '%s\n' "${!stepScripts[@]}" | sort -n))
  for stepName in "${stepNames[@]}"
  do
    echo "  ${stepName}"
  done
  exit 1
fi
