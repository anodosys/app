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
  -c  script
  -p  Parameter list (optional)
  -u  User name (optional)

Example: ${scriptName} -s web -c "/path/to/script.sh" -p "parameter1,parameter2,parameter3" -u www-data
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
script=
parameterList=
userName=

while getopts hs:c:p:u:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    c) script=$(trim "$OPTARG");;
    p) parameterList=$(trim "$OPTARG");;
    u) userName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

if [[ -z "${script}" ]]; then
  >&2 echo "No script specified!"
  usage
  exit 1
fi

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -n "${parameterList}" ]]; then
  readarray -td, parameters < <(printf "%s" "${parameterList}"); declare -p parameters
else
  parameters=()
fi

if [[ -n "${userName}" ]]; then
  containerExecuteUser "${containerName}" "${userName}" "${script}" "${parameters[@]}"
else
  containerExecute "${containerName}" "${script}" "${parameters[@]}"
fi
