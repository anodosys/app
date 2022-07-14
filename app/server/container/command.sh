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
  -u  User name (optional)
  -c  Command

Example: ${scriptName} -s web -u www-data -c "/test.sh"
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
userName=
command=

while getopts hs:u:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    u) userName=$(trim "$OPTARG");;
    c) command=$(trim "$OPTARG");;
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
  containerCommand "${containerName}" "sudo -H -u \"${userName}\" bash -c \"${command}\""
else
  containerCommand "${containerName}" "${command}"
fi
