#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- System remove -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeRemoveScript}" ]]; then
  echo "Before system remove script: ${beforeRemoveScript}"
  if [[ -n "${beforeRemoveParameters}" ]]; then
    "${beforeRemoveScript}" "${beforeRemoveParameters[@]}"
  else
    "${beforeRemoveScript}"
  fi
fi

systemRemove "${systemName}"

if [[ -n "${afterRemoveScript}" ]]; then
  echo "After system remove script: ${afterRemoveScript}"
  if [[ -n "${afterRemoveParameters}" ]]; then
    "${afterRemoveScript}" "${afterRemoveParameters[@]}"
  else
    "${afterRemoveScript}"
  fi
fi
