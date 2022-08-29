#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- System remove -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeSystemRemoveScript}" ]]; then
  echo "Before system remove script: ${beforeSystemRemoveScript}"
  if [[ -n "${beforeSystemRemoveParameters}" ]]; then
    "${beforeSystemRemoveScript}" "${beforeSystemRemoveParameters[@]}"
  else
    "${beforeSystemRemoveScript}"
  fi
fi

systemRemove "${systemName}"

if [[ -n "${afterSystemRemoveScript}" ]]; then
  echo "After system remove script: ${afterSystemRemoveScript}"
  if [[ -n "${afterSystemRemoveParameters}" ]]; then
    "${afterSystemRemoveScript}" "${afterSystemRemoveParameters[@]}"
  else
    "${afterSystemRemoveScript}"
  fi
fi
