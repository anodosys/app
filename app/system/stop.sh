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

if [[ -n "${beforeSystemStopScript}" ]]; then
  echo "Before system stop script: ${beforeSystemStopScript}"
  if [[ -n "${beforeSystemStopParameters}" ]]; then
    "${beforeSystemStopScript}" "${beforeSystemStopParameters[@]}"
  else
    "${beforeSystemStopScript}"
  fi
fi

systemAdd "${systemName}" "${configurationFileName}"
systemStop "${systemName}"

if [[ -n "${afterSystemStopScript}" ]]; then
  echo "After system stop script: ${afterSystemStopScript}"
  if [[ -n "${afterSystemStopParameters}" ]]; then
    "${afterSystemStopScript}" "${afterSystemStopParameters[@]}"
  else
    "${afterSystemStopScript}"
  fi
fi
