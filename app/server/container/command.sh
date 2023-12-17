#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name
  -c  Command
  -i  Flag if the command show by executed interactively (optional)
  -q  Flag if the command is hidden
  -u  User name (optional)

Example: ${scriptName} -s web -c "echo \"test\"" -u www-data
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
command=
interactive=0
quiet=0
userName=

while getopts hs:c:iqu:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    c) command=$(trim "$OPTARG");;
    i) interactive=1;;
    q) quiet=1;;
    u) userName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

if [[ -z "${command}" ]]; then
  >&2 echo "No command specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

logDisable

containerName="${systemName}_${serverName}"

if [[ -n "${userName}" ]]; then
  if [[ $(containerCommandQuiet "${containerName}" "getent passwd ${userName} | cat" | wc -l) == 0 ]]; then
    userId=$(getent passwd "${userName}" | tr ':' ' ' | awk '{print $3}')
    if [[ -n "${userId}" ]]; then
      userName=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | cat" | tr ':' ' ' | awk '{print $1}')
      if [[ -z "${userName}" ]]; then
        userName="${USER}"
        userHome=$(getent passwd "${userName}" | tr ':' ' ' | awk '{print $6}')
        groupId=$(stat -c '%g' "${userHome}")
        groupName=$(containerCommandQuiet "${containerName}" "getent group ${groupId} | tr ':' ' ' | awk '{print \$1}'")
        if [[ -z "${groupName}" ]]; then
          groupName="docker_volume_${groupId}"
          echo "Creating new group: ${groupName}"
          containerCommand "${containerName}" "groupadd -g ${groupId} ${groupName}"
        else
          echo "No need to create group: ${groupName}"
        fi
        targetUser="docker_volume_${userId}"
        echo "Creating new user: ${targetUser}"
        containerCommand "${containerName}" "useradd -m -u ${userId} -g ${groupId} ${targetUser}"
        userName="${targetUser}"
      fi
    fi
  fi
  if [[ "${quiet}" == 0 ]]; then
    containerCommand "${containerName}" "${command}" "${interactive}" "${userName}"
  else
    containerCommandQuiet "${containerName}" "${command}" "${interactive}" "${userName}"
  fi
else
  if [[ "${quiet}" == 0 ]]; then
    containerCommand "${containerName}" "${command}" "${interactive}"
  else
    containerCommandQuiet "${containerName}" "${command}" "${interactive}"
  fi
fi
