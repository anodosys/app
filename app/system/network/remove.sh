#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

if [[ -n "${beforeNetworkRemoveScript}" ]]; then
  echo "Before network remove script: ${beforeNetworkRemoveScript}"
  "${beforeNetworkRemoveScript}"
fi

echo "- Network remove -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

networkRemove "${systemName}"

if [[ -n "${afterNetworkRemoveScript}" ]]; then
  echo "After network remove script: ${afterNetworkRemoveScript}"
  "${afterNetworkRemoveScript}"
fi
