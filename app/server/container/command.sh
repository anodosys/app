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
  -u  User name (optional)

Example: ${scriptName} -s web -u www-data -c "/test.sh"
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
command=
interactive=0
userName=

while getopts hs:c:iu:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    c) command=$(trim "$OPTARG");;
    i) interactive=1;;
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

containerName="${systemName}_${serverName}"

if [[ -n "${userName}" ]]; then
  if [[ $(containerCommandQuiet "${containerName}" "getent passwd ${userName} | cat" | wc -l) == 0 ]]; then
    userId=$(getent passwd "${userName}" | tr ':' ' ' | awk '{print $3}')
    if [[ -n "${userId}" ]]; then
      userName=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | cat" | tr ':' ' ' | awk '{print $1}')
    fi
  fi
  containerCommand "${containerName}" "${command}" "${interactive}" "${userName}"
else
  containerCommand "${containerName}" "${command}" "${interactive}"
fi
