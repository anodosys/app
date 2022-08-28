#!/bin/bash -e

if [[ -z "${anodosysConfigurationFile}" ]]; then
  >&2 echo "No anodosys configuration file defined"
  exit 1
fi

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined!"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No anodosys user var configuration path defined!"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -c  Configuration hash

Example: ${scriptName} -c 1234567890
EOF
}

trim()
{
  echo -n "$1" | xargs
}

createConfigurationFile()
{
  local configurationHash="${1}"
  local serverName="${2}"
  local configurationFile

  configurationFile="${anodosysUserVarConfigurationPath}/${configurationHash}_${serverName}.ini"
  if [[ ! -f "${configurationFile}" ]]; then
    echo "Create configuration file at: ${configurationFile}"
    rm -rf "${configurationFile}"
    touch "${configurationFile}"
    echo "#!/bin/bash -e" >> "${configurationFile}"

    "${anodosysAppPath}/prepare-configuration.sh" \
      -s "${serverName}" \
      -o >> "${configurationFile}"
  fi
}

configurationHash=

while getopts hc:? option; do
  case "${option}" in
    h) usage; exit 1;;
    c) configurationHash=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${configurationHash}" ]]; then
  >&2 echo "No configuration hash specified!"
  usage
  exit 1
fi

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi

createConfigurationFile "${configurationHash}" "system"

configurationHashFile="${anodosysUserVarConfigurationPath}/${configurationHash}_system.ini"
configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_system.ini"

cp "${configurationHashFile}" "${configurationFile}"

setServerConfiguration "${systemName}" "system"

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

if [[ -n "${beforeContainerConfigurationScript}" ]]; then
  echo "Before container configuration script: ${beforeContainerConfigurationScript}"
  "${beforeContainerConfigurationScript}"
fi

processIds=( )
for serverName in "${serverNames[@]}"; do
  createConfigurationFile "${configurationHash}" "${serverName}" &
  processId=$!
  processIds+=( "${processId}" )
done

for processId in ${processIds[*]}; do
  wait "${processId}"
done

for serverName in "${serverNames[@]}"; do
  configurationHashFile="${anodosysUserVarConfigurationPath}/${configurationHash}_${serverName}.ini"
  configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"

  cp "${configurationHashFile}" "${configurationFile}"
done

if [[ -n "${afterContainerConfigurationScript}" ]]; then
  echo "After container configuration script: ${afterContainerConfigurationScript}"
  "${afterContainerConfigurationScript}"
fi
