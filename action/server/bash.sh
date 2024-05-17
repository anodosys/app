#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

resetBashPath=

shift
if [[ -n "${1}" ]]; then
  serverName="${1}"
  shift

  setServerConfiguration "${systemName}" "system"

  if [[ -n "${bashServer}" ]] && [[ "${bashServer}" != "${serverName}" ]] && [[ -n "${bashPath}" ]]; then
    resetBashPath="${bashPath}"
  fi
else
  if [[ -z "${systemName}" ]]; then
    >&2 echo "No system name specified!"
    exit 1
  fi

  setServerConfiguration "${systemName}" "system"

  if [[ -n "${bashServer}" ]]; then
    serverName="${bashServer}"
  elif [[ -n "${serverNames}" ]]; then
    if [[ "${#serverNames[@]}" -eq 1 ]]; then
      serverName="${serverNames[0]}"
    fi
  fi
fi

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name"
  exit 1
fi

if [[ -n "${1}" ]]; then
  userName="${1}"
  shift
else
  if [[ -z "${systemName}" ]]; then
    >&2 echo "No system name specified!"
    exit 1
  fi

  setServerConfiguration "${systemName}" "${serverName}"

  if [[ -n "${bashUser}" ]]; then
    userName="${bashUser}"
  fi
fi

if [[ -z "${userName}" ]]; then
  userName="none"
fi

if [[ "${userName}" == "me" ]]; then
  userName="${USER}"
fi

if [[ -n "${1}" ]]; then
  path="${1}"
  shift
else
  if [[ -z "${systemName}" ]]; then
    >&2 echo "No system name specified!"
    exit 1
  fi

  if [[ -n "${resetBashPath}" ]]; then
    bashPath=
  fi

  setServerConfiguration "${systemName}" "${serverName}"

  if [[ -n "${bashPath}" ]]; then
    path="${bashPath}"
  fi
fi

if [[ -n "${path}" ]]; then
  command="bash --rcfile <(echo 'cd ${path}')"
else
  command="bash --rcfile <(echo 'cd ~')"
fi

"${anodosysAppPath}/server/container/command.sh" \
  -s "${serverName}" \
  -u "${userName}" \
  -c "${command}" \
  -i \
  -q
