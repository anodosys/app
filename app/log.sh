#!/bin/bash -e

logPrefix=
logFile=
# set to the log file once a pipeline without terminal writes it, so that child processes do not write it again
logFileCaptured="${logFileCaptured:-}"

# a log file larger than this (in bytes) is rotated when the next run of the system starts
logMaxSize=10485760


logName()
{
  if [[ $(hash ts >/dev/null 2>&1 && echo "yes" || echo "no") == "yes" ]]; then
    # every system writes into its own log file, named after the first part of the prefix (the system name)
    if [[ -n "${anodosysUserVarLogPath}" ]] && [[ -n "${1}" ]]; then
      logFile="${anodosysUserVarLogPath}/${1}.log"
    fi
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

logStart()
{
  local systemLogFile

  if [[ -z "${anodosysUserVarLogPath}" ]] || [[ -z "${1}" ]]; then
    return 0
  fi

  systemLogFile="${anodosysUserVarLogPath}/${1}.log"
  shift

  if [[ -f "${systemLogFile}" ]] && [[ $(stat -c %s "${systemLogFile}") -gt "${logMaxSize}" ]]; then
    mv -f "${systemLogFile}" "${systemLogFile}.1"
  fi

  printf '\n===== %s | %s | %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" "$(pwd)" >> "${systemLogFile}"
}

# shellcheck disable=SC2034
typeset -fx logStart

logDisable()
{
  if sh -c ": >/dev/tty" >/dev/null 2>/dev/null; then
    exec >/dev/tty
    exec 2>/dev/tty
  fi
}

# shellcheck disable=SC2034
typeset -fx logDisable

logEnable()
{
  local writeLogFile=0
  local esc=$'\e'
  local cr=$'\r'
  local bel=$'\a'
  local logFileFilter

  # sed script that turns terminal output into plain log file lines:
  # 1. remove color codes
  # 2. remove trailing carriage returns (output of docker exec -t ends with \r\n)
  # 3. collapse progress output to its last state: keep the [system] [server] prefix and the text after the last
  #    carriage return, cursor to line start (ESC[G, ESC[1G) or clear line (ESC[2K)
  # 4. remove all other control sequences (cursor movement, ESC[K, cursor visibility, ...)
  # 5. remove window title sequences (ESC]...BEL)
  # 6. remove remaining carriage returns
  logFileFilter="s/${esc}\[[0-9;]*m//g"
  logFileFilter+=";s/${cr}+\$//"
  logFileFilter+=";s/^((\[[^]]*\] )*).*(${cr}|${esc}\[[01]?G|${esc}\[2K)/\1/"
  logFileFilter+=";s/${esc}\[[0-9;?]*[A-Za-z]//g"
  logFileFilter+=";s/${esc}\][^${bel}]*${bel}//g"
  logFileFilter+=";s/${cr}//g"

  if [[ -n "${logFile}" ]]; then
    if sh -c ": >/dev/tty" >/dev/null 2>/dev/null; then
      # with a terminal, every process writes its own output to the terminal and therefore also to the log file
      writeLogFile=1
    elif [[ "${logFileCaptured}" != "${logFile}" ]]; then
      # without a terminal, the output of child processes passes through this pipeline, so only the outermost one
      # writes to the log file
      writeLogFile=1
      logFileCaptured="${logFile}"
      export logFileCaptured
    fi
  fi

  if [[ "${writeLogFile}" == 1 ]]; then
    # the terminal gets colored output, the log file the same lines without control codes
    exec > >(ts "${logPrefix}" | tee >(sed -E -u "${logFileFilter}" >> "${logFile}") | sed $'s,.*,\e[0;37m&\e[m,')
    exec 2> >(ts "${logPrefix}" | tee >(sed -E -u "${logFileFilter}" >> "${logFile}") | sed $'s,.*,\e[1;31m&\e[m,' >&2)
  else
    exec > >(ts "${logPrefix}" | sed $'s,.*,\e[0;37m&\e[m,')
    exec 2> >(ts "${logPrefix}" | sed $'s,.*,\e[1;31m&\e[m,' >&2)
  fi
}

# shellcheck disable=SC2034
typeset -fx logEnable
