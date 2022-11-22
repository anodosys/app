#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${configurationFileName}" ]]; then
  >&2 echo "No configuration file name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- System add -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeAddScript}" ]]; then
  echo "Before system add script: ${beforeAddScript}"
  if [[ -n "${beforeStartParameters}" ]]; then
    "${beforeAddScript}" "${beforeStartParameters[@]}"
  else
    "${beforeAddScript}"
  fi
fi

systemAdd "${systemName}" "${configurationFileName}"
systemStop "${systemName}"

if [[ -n "${afterAddScript}" ]]; then
  echo "After system add script: ${afterAddScript}"
  if [[ -n "${afterAddParameters}" ]]; then
    "${afterAddScript}" "${afterAddParameters[@]}"
  else
    "${afterAddScript}"
  fi
fi
