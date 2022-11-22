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

echo "- System stop -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeStopScript}" ]]; then
  echo "Before system stop script: ${beforeStopScript}"
  if [[ -n "${beforeStopParameters}" ]]; then
    "${beforeStopScript}" "${beforeStopParameters[@]}"
  else
    "${beforeStopScript}"
  fi
fi

systemAdd "${systemName}" "${configurationFileName}"
systemStop "${systemName}"

if [[ -n "${afterStopScript}" ]]; then
  echo "After system stop script: ${afterStopScript}"
  if [[ -n "${afterStopParameters}" ]]; then
    "${afterStopScript}" "${afterStopParameters[@]}"
  else
    "${afterStopScript}"
  fi
fi
