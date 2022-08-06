#!/bin/bash -e

logPrefix=

logName()
{
  if [[ $(hash ts >/dev/null 2>&1 && echo "yes" || echo "no") == "yes" ]]; then
    logPrefix="[${1}]"
    shift
    while [[ "$#" -gt 0 ]]; do
      logPrefix+=" [${1}]"
      shift
    done
    logDisable
    logEnable
  fi
}

# shellcheck disable=SC2034
typeset -fx logName

logDisable()
{
  exec >/dev/tty
  exec 2>/dev/tty
}

# shellcheck disable=SC2034
typeset -fx logDisable

logEnable()
{
  exec > >(ts "${logPrefix}" | sed $'s,.*,\e[0;37m&\e[m,')
  exec 2> >(ts "${logPrefix}" | sed $'s,.*,\e[1;31m&\e[m,' >&2)
}

# shellcheck disable=SC2034
typeset -fx logEnable
