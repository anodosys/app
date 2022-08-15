#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

echo "- System remove -" | sed $'s,.*,\e[1;37m&\e[m,'

systemRemove "${systemName}"
