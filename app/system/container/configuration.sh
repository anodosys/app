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

createConfigurationFile()
{
  local systemName="${1}"
  local serverName="${2}"
  local configurationFile

  configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"
  echo "Create configuration file at: ${configurationFile}"
  rm -rf "${configurationFile}"
  touch "${configurationFile}"
  echo "#!/bin/bash -e" >> "${configurationFile}"

  "${anodosysAppPath}/prepare-configuration.sh" \
    -s "${serverName}" \
    -o >> "${configurationFile}"
}

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi

createConfigurationFile "${systemName}" "system"

setServerConfiguration "${systemName}" "system"

echo "- Container configuration -" | sed $'s,.*,\e[1;37m&\e[m,'

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
  createConfigurationFile "${systemName}" "${serverName}" &
  processIds+=( $! )
done

for processId in ${processIds[*]}; do
  wait "${processId}"
done

if [[ -n "${afterContainerConfigurationScript}" ]]; then
  echo "After container configuration script: ${afterContainerConfigurationScript}"
  "${afterContainerConfigurationScript}"
fi
