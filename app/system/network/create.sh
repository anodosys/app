#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

if [[ -n "${beforeNetworkCreateScript}" ]]; then
  echo "Before network create script: ${beforeNetworkCreateScript}"
  "${beforeNetworkCreateScript}"
fi

echo "- Network create -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

networkCreate "${systemName}"

if [[ -n "${afterNetworkCreateScript}" ]]; then
  echo "After network create script: ${afterNetworkCreateScript}"
  "${afterNetworkCreateScript}"
fi
