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

if [[ -n "${beforeSystemStartScript}" ]]; then
  echo "Before system start script: ${beforeSystemStartScript}"
  if [[ -n "${beforeSystemStartParameters}" ]]; then
    "${beforeSystemStartScript}" "${beforeSystemStartParameters[@]}"
  else
    "${beforeSystemStartScript}"
  fi
fi

systemAdd "${systemName}" "${configurationFileName}"
systemStart "${systemName}"

if [[ -n "${afterSystemStartScript}" ]]; then
  echo "After system start script: ${afterSystemStartScript}"
  if [[ -n "${afterSystemStartParameters}" ]]; then
    "${afterSystemStartScript}" "${afterSystemStartParameters[@]}"
  else
    "${afterSystemStartScript}"
  fi
fi
