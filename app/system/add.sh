#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

if [[ -z "${configurationFileName}" ]]; then
  >&2 echo "No configuration file name specified!"
  exit 1
fi

echo "- System add -" | sed $'s,.*,\e[1;37m&\e[m,'

systemAdd "${systemName}" "${configurationFileName}"
systemStop "${systemName}"
