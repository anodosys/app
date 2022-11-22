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

echo "- System start -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeStartScript}" ]]; then
  echo "Before system start script: ${beforeStartScript}"
  if [[ -n "${beforeStartParameters}" ]]; then
    "${beforeStartScript}" "${beforeStartParameters[@]}"
  else
    "${beforeStartScript}"
  fi
fi

systemAdd "${systemName}" "${configurationFileName}"
systemStart "${systemName}"

if [[ -n "${afterStartScript}" ]]; then
  echo "After system start script: ${afterStartScript}"
  if [[ -n "${afterStartParameters}" ]]; then
    "${afterStartScript}" "${afterStartParameters[@]}"
  else
    "${afterStartScript}"
  fi
fi
