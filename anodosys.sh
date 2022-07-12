#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} <ACTION>

ACTION:
  build     Build the images if required
  rebuild   Re-build the images if required
  pull      Pull the images required for building and starting
  install   Build the containers, but do not create images
  image     Build the image from running containers
  destroy   Destroy the images
  start     Start the containers
  restart   Re-start the containers
  stop      Stop the constainers
  remove    Remove the constainers
  cmd       Execute a command in a container
  config    Show the complete configuration

Example: ${scriptName} build
EOF
}

trim()
{
  echo -n "$1" | xargs
}

logName()
{
  local prefix
  local logName="${1}"
  if [[ $(hash ts >/dev/null 2>&1 && echo "yes" || echo "no") == "yes" ]]; then
    prefix="[${1}]"
    shift
    while [[ "$#" -gt 0 ]]; do
      prefix+=" [${1}]"
      shift
    done
    exec >/dev/tty
    exec 2>/dev/tty
    exec > >(ts "${prefix}" | sed $'s,.*,\e[0;37m&\e[m,')
    exec 2> >(ts "${prefix}" | sed $'s,.*,\e[1;31m&\e[m,' >&2)
  fi
}

collectConfigurationFiles()
{
  local anodosysFileName="${1}"

  if [[ -z "${anodosysFileName}" ]] && [[ -f "anodosys.json" ]]; then
    anodosysFileName="anodosys.json"
  elif [[ -z "${anodosysFileName}" ]] && [[ -f "ads.json" ]]; then
    anodosysFileName="ads.json"
  fi

  if [[ ! -f "${anodosysFileName}" ]]; then
    >&2 echo "Could not find configuration at: ${anodosysFileName}"
    exit 1
  fi

  anodosysFileName=$(realpath "${anodosysFileName}")

  #>&2 echo "Parsing: ${anodosysFileName}"
  configurationFiles=( "${anodosysFileName}" )

  oldIFS="${IFS}"
  IFS=$'\n'
  requireFileNames=( $(jq -r '.require | if type=="array" then values[] else . end //empty' "${anodosysFileName}") )
  IFS="${oldIFS}"
  #>&2 echo "requireFileNames: ${requireFileNames[*]}"
  if [[ "${#requireFileNames[@]}" -gt 0 ]]; then
    for requireFileName in "${requireFileNames[@]}"; do
      requireFileName=$(completePath "${anodosysFileName}" "require" "${requireFileName}")
      requiredConfigurationFiles=( $(collectConfigurationFiles "${requireFileName}") )
      requiredConfigurationFiles=( $(printf '%s\n' "${requiredConfigurationFiles[@]}" | tac | tr '\n' ' '; echo) )
      for requiredConfigurationFile in "${requiredConfigurationFiles[@]}"; do
        configurationFiles=("${requiredConfigurationFile}" "${configurationFiles[@]}")
      done
    done
  fi

  oldIFS="${IFS}"
  IFS=$'\n'
  includeFileNames=( $(jq -r '.include | if type=="array" then values[] else . end //empty' "${anodosysFileName}") )
  IFS="${oldIFS}"
  #>&2 echo "includeFileNames: ${includeFileNames[*]}"
  if [[ "${#includeFileNames[@]}" -gt 0 ]]; then
    for includeFileName in "${includeFileNames[@]}"; do
      includeFileName=$(completePath "${anodosysFileName}" "include" "${includeFileName}")
      includedConfigurationFiles=( $(collectConfigurationFiles "${includeFileName}") )
      for includedConfigurationFile in "${includedConfigurationFiles[@]}"; do
        configurationFiles+=("${includedConfigurationFile}")
      done
    done
  fi

  #>&2 echo "configurationFiles: ${configurationFiles[*]}"
  echo "${configurationFiles[@]}"
}

prepareConfigurationFiles()
{
  local configurationFiles=( "${@}" )
  local configurationFile
  local configurationFileNameHash
  local configurationFileContentHash
  local preparedConfigurationFiles
  local preparedConfigurationFile
  local configurationJson
  local preparedConfigurationJson

  preparedConfigurationFiles=( )
  for configurationFile in "${configurationFiles[@]}"; do
    configurationFileNameHash=$(echo "${configurationFile}" | md5sum | awk '{print $1}')
    configurationFileContentHash=$(md5sum "${configurationFile}" | awk '{print $1}')
    preparedConfigurationFile="${anodosysUserVarConfigurationPath}/${configurationFileNameHash}_${configurationFileContentHash}.json"
    if [[ ! -f "${preparedConfigurationFile}" ]]; then
      >&2 echo "Preparing configuration file at: ${configurationFile}"
      configurationJson=$(cat "${configurationFile}")
      preparedConfigurationJson=$(prepareConfigurationJson "${configurationFile}" "${configurationJson}")
      >&2 echo "Storing parsed configuration in file at: ${preparedConfigurationFile}"
      echo "${preparedConfigurationJson}" > "${preparedConfigurationFile}"
    fi
    preparedConfigurationFiles+=("${preparedConfigurationFile}")
  done

  echo "${preparedConfigurationFiles[@]}"
}

prepareConfigurationJson()
{
  local configurationFile="${1}"
  local configurationJson="${2}"
  local preparedConfigurationJson
  local keys
  local key
  local type
  local subKeys
  local subKey
  local subConfigurationJson
  local simpleList
  local value
  local valueType
  local preparedValue

  preparedConfigurationJson="{}"

  keys=( $(echo "${configurationJson}" | jq -r 'keys_unsorted[]') )
  for key in "${keys[@]}"; do
    type=$(echo "${configurationJson}" | jq -r ".${key} | type")
    if [[ "${type}" == "array" ]]; then
      subKeys=( $(echo "${configurationJson}" | jq -r ".${key} | keys_unsorted[]") )
      simpleList=1
      for subKey in "${subKeys[@]}"; do
        if ! [[ "${subKey}" =~ ^[0-9]+$ ]]; then
          simpleList=0
        fi
      done
      for subKey in "${subKeys[@]}"; do
        value=$(echo "${configurationJson}" | jq -r ".${key}[${subKey}]")
        valueType=$(echo "${configurationJson}" | jq -r ".${key}[${subKey}] | type")
        if [[ "${value:0:1}" == "{" ]]; then
          preparedValue=$(prepareConfigurationJson "${configurationFile}" "${value}")
        else
          preparedValue=$(prepareValue "${value}")
          if [[ "${key}" == "containerVolumes" ]]; then
            readarray -d : -t valueParts < <(printf '%s' "${value}")
            sourcePath=$(completePath "${configurationFile}" "include" "${valueParts[0]}")
            if test "${valueParts[2]+isset}"; then
              preparedValue="${sourcePath}:${valueParts[1]}:${valueParts[2]}"
            else
              preparedValue="${sourcePath}:${valueParts[1]}"
            fi
          else
            preparedValue=$(completePath "${configurationFile}" "${key}" "${preparedValue}")
          fi
        fi
        if [[ "${simpleList}" == 1 ]]; then
          if [[ "${valueType}" == "string" ]]; then
            preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} += [\"${preparedValue}\"]")
          else
            preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} += [${preparedValue}]")
          fi
        else
          preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key}[${subKey}] = ${preparedValue}]")
        fi
      done
    fi
    if [[ "${type}" == "object" ]]; then
      subConfigurationJson=$(echo "${configurationJson}" | jq ".${key}")
      preparedSubConfigurationJson=$(prepareConfigurationJson "${configurationFile}" "${subConfigurationJson}")
      preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} = ${preparedSubConfigurationJson}")
    fi
    if [[ "${type}" == "string" ]] || [[ "${type}" == "number" ]] || [[ "${type}" == "boolean" ]] || [[ "${type}" == "null" ]]; then
      value=$(echo "${configurationJson}" | jq -r ".${key}")
      preparedValue=$(prepareValue "${value}")
      preparedValue=$(completePath "${configurationFile}" "${key}" "${preparedValue}")
      if [[ "${type}" == "string" ]]; then
        preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} = \"${preparedValue}\"")
      elif [[ "${type}" == "number" ]] || [[ "${type}" == "boolean" ]]; then
        preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} = ${preparedValue}")
      elif [[ "${type}" == "null" ]]; then
        preparedConfigurationJson=$(echo "${preparedConfigurationJson}" | jq ".${key} = null")
      fi
    fi
  done

  echo "${preparedConfigurationJson}"
}

completePath()
{
  local sourceFile="${1}"
  local key="${2}"
  local value="${3}"
  local sourceFilePath

  local canCompletePath=0
  if [[ "${key}" == "require" ]] || [[ "${key}" == "include" ]] || [[ "${key}" == "source" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "actionStartScript" ]] || [[ "${key}" == "actionFinishScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeNetworkCreateScript" ]] || [[ "${key}" == "networkCreateScript" ]] || [[ "${key}" == "afterNetworkCreateScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeNetworkRemoveScript" ]] || [[ "${key}" == "networkRemoveScript" ]] || [[ "${key}" == "afterNetworkRemoveScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageExistsScript" ]] || [[ "${key}" == "imageExistsScript" ]] || [[ "${key}" == "afterImageExistsScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImagePullScript" ]] || [[ "${key}" == "imagePullScript" ]] || [[ "${key}" == "afterImagePullScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageCreateScript" ]] || [[ "${key}" == "imageCreateScript" ]] || [[ "${key}" == "afterImageCreateScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImagePushScript" ]] || [[ "${key}" == "imagePushScript" ]] || [[ "${key}" == "afterImagePushScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageRemoveScript" ]] || [[ "${key}" == "imageRemoveScript" ]] || [[ "${key}" == "afterImageRemoveScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerConfigurationScript" ]] || [[ "${key}" == "containerConfigurationScript" ]] || [[ "${key}" == "afterContainerConfigurationScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerExistsScript" ]] || [[ "${key}" == "containerExistsScript" ]] || [[ "${key}" == "afterContainerExistsScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerCreateScript" ]] || [[ "${key}" == "containerCreateScript" ]] || [[ "${key}" == "afterContainerCreateScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerStartScript" ]] || [[ "${key}" == "containerStartScript" ]] || [[ "${key}" == "afterContainerStartScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerRunningScript" ]] || [[ "${key}" == "containerRunningScript" ]] || [[ "${key}" == "afterContainerRunningScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerPrepareScript" ]] || [[ "${key}" == "containerPrepareScript" ]] || [[ "${key}" == "afterContainerPrepareScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerInstallScript" ]] || [[ "${key}" == "containerInstallScript" ]] || [[ "${key}" == "afterContainerInstallScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerDismantleScript" ]] || [[ "${key}" == "containerDismantleScript" ]] || [[ "${key}" == "afterContainerDismantleScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerStopScript" ]] || [[ "${key}" == "containerStopScript" ]] || [[ "${key}" == "afterContainerStopScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerRemoveScript" ]] || [[ "${key}" == "containerRemoveScript" ]] || [[ "${key}" == "afterContainerRemoveScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${canCompletePath}" == 1 ]]; then
    if [[ "${value:0:1}" != "/" ]]; then
      sourceFilePath=$(dirname "${sourceFile}")
      if [[ -f "${sourceFilePath}/${value}" ]]; then
        realpath "${sourceFilePath}/${value}"
        exit 0
      else
        if [[ "${key}" == "require" ]] || [[ "${key}" == "include" ]]; then
          if [[ -f "${anodosysConfigurationPath}/${value}" ]]; then
            realpath "${anodosysConfigurationPath}/${value}"
            exit 0
          fi
          for anodosysExtension in "${anodosysExtensions[@]}"; do
            if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/configuration/${value}" ]]; then
              realpath "${anodosysExtensionPath}/${anodosysExtension}/configuration/${value}"
              exit 0
            fi
          done
        else
          if [[ -f "${anodosysScriptPath}/${value}" ]]; then
            realpath "${anodosysScriptPath}/${value}"
            exit 0
          fi
          for anodosysExtension in "${anodosysExtensions[@]}"; do
            if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/script/${value}" ]]; then
              realpath "${anodosysExtensionPath}/${anodosysExtension}/script/${value}"
              exit 0
            fi
          done
        fi
      fi
      echo "${sourceFilePath}/${value}"
      exit 0
    fi
  fi

  echo "${value}"
}

prepareValue()
{
  local text="$*"
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"
  text=$(printf '%s' "${text}")
  text="${text%\"}"
  text="${text#\"}"
  echo -n "${text}"
}

setServerConfiguration()
{
  local systemName="${1}"
  local serverName="${2}"
  configurationFile="${anodosysUserVarConfigurationPath}/${systemName}_${serverName}.ini"
  if [[ -f "${configurationFile}" ]]; then
    source "${configurationFile}"
  fi
}

networkExists()
{
  local networkName="${1}"
  docker network ls | tail -n +2 | awk '{print $2}' | grep -E "^${networkName}\$" | wc -l
}

networkCreate()
{
  local networkName="${1}"
  if [[ $(networkExists "${networkName}") == 0 ]]; then
    echo "Creating network: ${networkName}"
    result=$(docker network create "${networkName}" 2>&1 | cat)
    if [[ $(networkExists "${networkName}") == 1 ]]; then
      echo "Successfully created network: ${networkName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create network: ${networkName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create network: ${networkName}"
  fi
}

networkRemove()
{
  local networkName="${1}"
  if [[ $(networkExists "${networkName}") == 1 ]]; then
    echo "Removing network: ${networkName}"
    result=$(docker network rm "${networkName}" 2>&1 | cat)
    if [[ "${result}" == "${networkName}" ]]; then
      echo "Successfully removed network: ${networkName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove network: ${networkName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove network: ${networkName}"
  fi
}

volumeExists()
{
  local volumeName="${1}"
  docker volume ls | tail -n +2 | awk '{print $2}' | grep -E "^${volumeName}\$" | wc -l
}

volumeCreate()
{
  local volumeName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-none}"
  if [[ $(volumeExists "${volumeName}") == 0 ]]; then
    echo "Creating volume: ${volumeName} with source path: ${sourcePath} and target path: ${targetPath} accessible by user: ${targetUser}"
    result=$(docker volume create \
      --driver local \
      --opt type=none \
      --opt device="${sourcePath}" \
      --opt o=bind \
      --name "${volumeName}" \
      --label "sourcePath=${sourcePath}" \
      --label "targetPath=${targetPath}" \
      --label "targetUser=${targetUser}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully created volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create volume: ${volumeName}"
  fi
}

volumeRemove()
{
  local volumeName="${1}"
  if [[ $(volumeExists "${volumeName}") == 1 ]]; then
    echo "Removing volume: ${volumeName}"
    result=$(docker volume rm "${volumeName}" 2>&1 | cat)
    if [[ "${result}" == "${volumeName}" ]]; then
      echo "Successfully removed volume: ${volumeName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove volume: ${volumeName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove volume: ${volumeName}"
  fi
}

imageExists()
{
  local imageName="${1}"
  local imageTag="${2}"
  docker images | grep -E "^${imageName}\\s+${imageTag}\\s" | wc -l
}

imageExistsRemote()
{
  local imageName="${1}"
  local imageTag="${2}"
  docker manifest inspect "${imageName}:${imageTag}" >/dev/null 2>&1 && echo 1 || echo 0
}

imageCreate()
{
  local imageName="${1}"
  local imageTag="${2}"
  local containerName="${3}"
  local buildImageEntryPoint="${4}"
  if [[ $(containerExists "${containerName}") == 1 ]]; then
    echo "Creating image: ${imageName}:${imageTag} from container: ${containerName}"
    if [[ -n "${buildImageEntryPoint}" ]]; then
      result=$(docker commit --change="ENTRYPOINT ${buildImageEntryPoint}" "${containerName}" "${imageName}:${imageTag}" 2>&1 | cat)
    else
      result=$(docker commit "${containerName}" "${imageName}:${imageTag}" 2>&1 | cat)
    fi
    if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
      echo "Successfully created image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create image: ${imageName}:${imageTag}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    >&2 echo "Container does not exist: ${containerName}"
    exit 1
  fi
}

imagePull()
{
  local imageName="${1}"
  local imageTag="${2}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
    echo "Pulling image: ${imageName}:${imageTag}"
    docker pull "${imageName}:${imageTag}"
  else
    echo "No need to pull image: ${imageName}:${imageTag}"
  fi
}

imagePush()
{
  local imageName="${1}"
  local imageTag="${2}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Pushing image: ${imageName}:${imageTag}"
    docker push "${imageName}:${imageTag}"
  else
    >&2 echo "Image does not exist: ${imageName}:${imageTag}"
    exit 1
  fi
}

imageRemove()
{
  local imageName="${1}"
  local imageTag="${2}"
  if [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    echo "Removing image: ${imageName}:${imageTag}"
    result=$(docker image rm "${imageName}:${imageTag}" 2>&1 | cat)
    if [[ $(imageExists "${imageName}" "${imageTag}") == 0 ]]; then
      echo "Successfully removed image: ${imageName}:${imageTag}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove image: ${imageName}:${imageTag}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to remove image: ${imageName}:${imageTag}"
  fi
}

containerExists()
{
  local containerName="${1}"
  docker ps -a | grep -E "\\s${containerName}\$" | wc -l
}

containerRunning()
{
  local containerName="${1}"
  docker ps | grep -E "\\s${containerName}\$" | wc -l
}

containerCreate()
{
  local imageName="${1}"
  shift
  local containerName="${1}"
  shift
  local networkName="${1}"
  shift
  local parameters=("$@")
  if [[ $(containerRunning "${containerName}") == 0 ]] && [[ $(containerExists "${containerName}") == 0 ]]; then
    command="docker create --tty --network \"${networkName}\""
    for parameter in "${parameters[@]}"; do
      if [[ "${parameter:0:11}" == "entryPoint:" ]]; then
        command+=" --entrypoint \"${parameter:11}\""
      elif [[ "${parameter:0:6}" == "alias:" ]]; then
        command+=" --network-alias \"${parameter:6}\""
      elif [[ "${parameter:0:5}" == "port:" ]]; then
        command+=" --publish ${parameter:5}"
      elif [[ "${parameter:0:7}" == "expose:" ]]; then
        command+=" --expose ${parameter:7}"
      elif [[ "${parameter:0:7}" == "volume:" ]]; then
        readarray -d : -t parameterParts < <(printf '%s' "${parameter:7}")
        sourcePath="${parameterParts[0]}"
        targetPath="${parameterParts[1]}"
        if test "${parameterParts[2]+isset}"; then
          targetUser="${parameterParts[2]}"
        else
          targetUser="none"
        fi
        sourcePath=$(realpath "${sourcePath}")
        containerVolumeCreate "${containerName}" "${sourcePath}" "${targetPath}" "${targetUser}"
        local sourceName=
        sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
        local volumeName
        volumeName="${containerName}_${sourceName}"
        command+=" --mount source=${volumeName},destination=${targetPath}"
      fi
    done
    command+=" --name \"${containerName}\" \"${imageName}\""
    echo "Creating container: ${containerName} with image: ${imageName}"
    result=$(bash -c "${command}" 2>&1 | cat)
    if [[ $(containerExists "${containerName}") == 1 ]]; then
      echo "Successfully created container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not create container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to create container: ${containerName}"
  fi
}

containerVolumeCreate()
{
  local containerName="${1}"
  local sourcePath="${2}"
  local targetPath="${3}"
  local targetUser="${4:-none}"
  if [[ ! -e "${sourcePath}" ]]; then
    mkdir -p "${sourcePath}"
  fi
  local sourceName=
  sourceName=$(echo "${sourcePath}" | sed 's/[^[:alnum:]]/_/g')
  local volumeName
  volumeName="${containerName}_${sourceName}"
  if [[ -n "${targetUser}" ]]; then
    volumeCreate "${volumeName}" "${sourcePath}" "${targetPath}" "${targetUser}"
  else
    volumeCreate "${volumeName}" "${sourcePath}" "${targetPath}"
  fi
}

containerVolumeList()
{
  local containerName="${1}"
  docker inspect -f "{{ json .Mounts }}" "${containerName}" | jq -r '.[].Name // empty'
}

containerVolumePrepare()
{
  local containerName="${1}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeNames=( $(containerVolumeList "${containerName}" ) )
    IFS="${oldIFS}"
    for volumeName in "${volumeNames[@]}"; do
      volumeName=$(trim "${volumeName}")
      if [[ $(volumeExists "${volumeName}") == 1 ]]; then
        echo "Preparing volume: ${volumeName}"
        sourcePath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".sourcePath // empty")
        targetPath=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetPath // empty")
        targetUser=$(docker volume inspect -f "{{ json .Labels }}" "${volumeName}" | jq -r ".targetUser // empty")
        if [[ -n "${sourcePath}" ]] && [[ -n "${targetPath}" ]] && [[ "${targetUser}" != "none" ]]; then
          echo "Preparing target path: ${targetPath}"
          groupId=$(containerCommandQuiet "${containerName}" "stat -c '%g' ${targetPath}")
          groupId=$(prepareValue "${groupId}")
          groupName=$(containerCommandQuiet "${containerName}" "stat -c '%G' ${targetPath}")
          groupName=$(prepareValue "${groupName}")
          if [[ "${groupName}" == "UNKNOWN" ]]; then
            groupName="docker_volume_${groupId}"
            echo "Creating new group: ${groupName}"
            containerCommand "${containerName}" "groupadd -g ${groupId} ${groupName}"
          fi
          if [[ $(containerCommandQuiet "${containerName}" "id -nG ${targetUser} | grep -w ${groupName} | wc -l") == 0 ]]; then
            echo "Adding user: ${targetUser} to group: ${groupName}"
            containerCommand "${containerName}" "usermod -a -G ${groupName} ${targetUser}"
          else
            echo "No need to add user: ${targetUser} to group: ${groupName}"
          fi
        else
          echo "No need to prepare path: ${targetPath}"
        fi
      else
        >&2 echo "Volume does not exist: ${volumeName}"
        exit 1
      fi
    done
  else
    echo "Not possible to prepare volumes of container: ${containerName}"
  fi
}

containerStart()
{
  local containerName="${1}"
  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ $(containerRunning "${containerName}") == 0 ]]; then
      echo "Starting container: ${containerName}"
      result=$(docker start "${containerName}" 2>&1 | cat)
      if [[ "${result}" == "${containerName}" ]]; then
        echo "Successfully started container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
      else
        >&2 echo "Could not start container: ${containerName}"
        >&2 echo "${result}"
        exit 1
      fi
      containerVolumePrepare "${containerName}"
      containerHostNameAdd "${containerName}"
      ports=( $(containerPorts "${containerName}") )
      if [[ "${#ports[@]}" -gt 0 ]]; then
        echo "Checking if all ports are available: ${containerName}"
        counter=0
        while [[ $(containerPortsAvailable "${containerName}") == 0 ]] && [[ "${counter}" -lt 120 ]]; do
          echo "Waiting until ports are available for container: ${containerName}" | sed $'s,.*,\e[1;30m&\e[m,'
          counter=$(( counter + 1 ))
          sleep 1
        done
        if [[ $(containerPortsAvailable "${containerName}") == 1 ]]; then
          echo "All ports are available for containerName: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
        else
          >&2 echo "Not all ports are available for containerName: ${containerName}"
          exit 1
        fi
      fi
    else
      echo "No need to start container: ${containerName}"
    fi
  else
    >&2 echo "Container does not exist: ${containerName}"
    exit 1
  fi
}

containerRun()
{
  local imageName="${1}"
  local containerName="${2}"
  if [[ $(containerRunning "${containerName}") == 0 ]]; then
    echo "Running container: ${containerName}"
    docker run -itd --name "${containerName}" "${imageName}"
    containerHostNameAdd "${containerName}"
  else
    echo "No need to start container: ${containerName}"
  fi
}

containerHostNameAdd()
{
  local containerName="${1}"
  local ipAddress=
  ipAddress=$(docker inspect -f "{{ json .NetworkSettings }}" "${containerName}" | jq -r '.Networks[].IPAddress')
  if [[ -f /etc/hosts ]]; then
    if [[ -w /etc/hosts ]]; then
      if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -eq 0 ]]; then
        echo "Adding host entry: ${ipAddress} ${containerName}"
        echo "${ipAddress} ${containerName}" >> /etc/hosts
      else
        lineNumber=$(grep -En "\s+${containerName}\s*$" /etc/hosts | awk -F: '{print $1}')
        echo "Update host entry: ${ipAddress} ${containerName}"
        sed -i "${lineNumber}s/.*/${ipAddress} ${containerName}/" /etc/hosts
      fi
    else
      echo "/etc/hosts is not writable for current user"
    fi
  fi
}

containerStop()
{
  local containerName="${1}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Stopping container: ${containerName}"
    result=$(docker stop "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully stopped container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not stop container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
    containerHostNameRemove "${containerName}"
  else
    echo "No need to stop container: ${containerName}"
  fi
}

containerRestart()
{
  local containerName="${1}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Restarting container: ${containerName}"
    result=$(docker restart "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully restarted container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
      ports=( $(containerPorts "${containerName}") )
      if [[ "${#ports[@]}" -gt 0 ]]; then
        echo "Checking if all ports are available: ${containerName}"
        counter=0
        while [[ $(containerPortsAvailable "${containerName}") == 0 ]] && [[ "${counter}" -lt 120 ]]; do
          echo "Waiting until ports are available for container: ${containerName}" | sed $'s,.*,\e[1;30m&\e[m,'
          counter=$(( counter + 1 ))
          sleep 1
        done
        if [[ $(containerPortsAvailable "${containerName}") == 1 ]]; then
          echo "All ports are available for containerName: ${containerName}" | sed $'s,.*,\e[0;36m&\e[m,'
        else
          >&2 echo "Not all ports are available for containerName: ${containerName}"
          exit 1
        fi
      fi
    else
      >&2 echo "Could not restart container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
  else
    echo "No need to restart container: ${containerName}"
  fi
}

containerHostNameRemove()
{
  local containerName="${1}"
  if [[ -f /etc/hosts ]]; then
    if [[ $(grep -E "\s+${containerName}\s*$" /etc/hosts | wc -l) -gt 0 ]]; then
      lineNumber=$(grep -En "\s+${containerName}\s*$" /etc/hosts | awk -F: '{print $1}')
      echo "Removing host entry: ${containerName}"
      sed -i "${lineNumber}d" /etc/hosts
    fi
  fi
}

containerRemove()
{
  local containerName="${1}"
  if [[ $(containerExists "${containerName}") == 1 ]]; then
    oldIFS="${IFS}"
    IFS=$'\n'
    volumeNames=( $(containerVolumeList "${containerName}" ) )
    IFS="${oldIFS}"
    echo "Removing container: ${containerName}"
    result=$(docker rm "${containerName}" 2>&1 | cat)
    if [[ "${result}" == "${containerName}" ]]; then
      echo "Successfully removed container: ${containerName}" | sed $'s,.*,\e[0;32m&\e[m,'
    else
      >&2 echo "Could not remove container: ${containerName}"
      >&2 echo "${result}"
      exit 1
    fi
    for volumeName in "${volumeNames[@]}"; do
      volumeName=$(trim "${volumeName}")
      volumeRemove "${volumeName}"
    done
  else
    echo "No need to remove container: ${containerName}"
  fi
}

containerIp()
{
  local containerName="${1}"
  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containerName}"
}

containerPorts()
{
  local containerName="${1}"
  docker container inspect -f "{{ json . }}" "${containerName}" | jq -r ".NetworkSettings .Ports | keys[] // empty"
}

containerPortsAvailable()
{
  local containerName="${1}"
  local ports
  local portParts
  local port
  local protocol

  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    ports=( $(containerPorts "${containerName}") )
    for port in "${ports[@]}"; do
      readarray -d / -t portParts < <(printf '%s' "${port}")
      port="${portParts[0]}"
      protocol="${portParts[1]}"
      portAvailable=$(docker exec "${containerName}" bash -c "echo > /dev/${protocol}/127.0.0.1/${port} 2>/dev/null && echo 1 || echo 0" 2>/dev/null || echo 0)
      if [[ "${portAvailable}" == 0 ]]; then
        echo 0
        exit 0
      fi
    done
    echo 1
  else
    echo 0
  fi
}

containerCopy()
{
  local containerName="${1}"
  local localFileName="${2}"
  local remoteFileName="${3}"
  if [[ -z "${remoteFileName}" ]]; then
    remoteFileName=$(basename "${localFileName}")
  fi
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Copying file from: ${localFileName} to container: ${containerName} at: ${remoteFileName}"
    docker cp "${localFileName}" "${containerName}:${remoteFileName}"
  else
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
}

containerCopyQuiet()
{
  local containerName="${1}"
  local localFileName="${2}"
  local remoteFileName="${3}"
  if [[ -z "${remoteFileName}" ]]; then
    remoteFileName=$(basename "${localFileName}")
  fi
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    docker cp "${localFileName}" "${containerName}:${remoteFileName}"
  fi
}

containerExecute()
{
  local containerName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")

  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopy "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      echo "Executing script in container at: /${remoteFileName}"
      docker exec "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    else
      >&2 echo "Container not running: ${containerName}"
      exit 1
    fi
  else
    >&2 echo "Could not find file at: ${localFileName}"
    exit 1
  fi
}

containerExecuteQuiet()
{
  local containerName="${1}"
  shift
  local localFileName="${1}"
  shift
  local parameters=("$@")
  if [[ -f "${localFileName}" ]]; then
    if [[ $(containerRunning "${containerName}") == 1 ]]; then
      containerCopyQuiet "${containerName}" "${localFileName}"
      remoteFileName=$(basename "${localFileName}")
      docker exec "${containerName}" "/${remoteFileName}" "${parameters[@]}"
    fi
  fi
}

containerCommand()
{
  local containerName="${1}"
  local command="${2}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    echo "Executing command in container: ${command}"
    docker exec -t "${containerName}" bash -c "${command}"
  else
    >&2 echo "Container not running: ${containerName}"
    exit 1
  fi
}

containerCommandQuiet()
{
  local containerName="${1}"
  local command="${2}"
  if [[ $(containerRunning "${containerName}") == 1 ]]; then
    docker exec "${containerName}" bash -c "${command}"
  fi
}

# shellcheck disable=SC2034
typeset -fx logName
# shellcheck disable=SC2034
typeset -fx prepareValue
# shellcheck disable=SC2034
typeset -fx setServerConfiguration
# shellcheck disable=SC2034
typeset -fx networkExists
# shellcheck disable=SC2034
typeset -fx networkCreate
# shellcheck disable=SC2034
typeset -fx networkRemove
# shellcheck disable=SC2034
typeset -fx volumeExists
# shellcheck disable=SC2034
typeset -fx volumeCreate
# shellcheck disable=SC2034
typeset -fx volumeRemove
# shellcheck disable=SC2034
typeset -fx imageExists
# shellcheck disable=SC2034
typeset -fx imageExistsRemote
# shellcheck disable=SC2034
typeset -fx imageCreate
# shellcheck disable=SC2034
typeset -fx imagePull
# shellcheck disable=SC2034
typeset -fx imagePush
# shellcheck disable=SC2034
typeset -fx imageRemove
# shellcheck disable=SC2034
typeset -fx containerExists
# shellcheck disable=SC2034
typeset -fx containerRunning
# shellcheck disable=SC2034
typeset -fx containerCreate
# shellcheck disable=SC2034
typeset -fx containerVolumeCreate
# shellcheck disable=SC2034
typeset -fx containerVolumePrepare
# shellcheck disable=SC2034
typeset -fx containerVolumeList
# shellcheck disable=SC2034
typeset -fx containerStart
# shellcheck disable=SC2034
typeset -fx containerRun
# shellcheck disable=SC2034
typeset -fx containerHostNameAdd
# shellcheck disable=SC2034
typeset -fx containerStop
# shellcheck disable=SC2034
typeset -fx containerRestart
# shellcheck disable=SC2034
typeset -fx containerHostNameRemove
# shellcheck disable=SC2034
typeset -fx containerRemove
# shellcheck disable=SC2034
typeset -fx containerIp
# shellcheck disable=SC2034
typeset -fx containerPorts
# shellcheck disable=SC2034
typeset -fx containerPortsAvailable
# shellcheck disable=SC2034
typeset -fx containerCopy
# shellcheck disable=SC2034
typeset -fx containerCopyQuiet
# shellcheck disable=SC2034
typeset -fx containerExecute
# shellcheck disable=SC2034
typeset -fx containerExecuteQuiet
# shellcheck disable=SC2034
typeset -fx containerCommand
# shellcheck disable=SC2034
typeset -fx containerCommandQuiet

action="${1}"
if [[ -z "${action}" ]]; then
  >&2 echo "No action defined!"
  usage
  exit 1
fi
if [[ "${action}" != "build" ]] && [[ "${action}" != "rebuild" ]] && [[ "${action}" != "pull" ]] && [[ "${action}" != "install" ]] && [[ "${action}" != "image" ]] && [[ "${action}" != "destroy" ]] && [[ "${action}" != "start" ]] && [[ "${action}" != "restart" ]] && [[ "${action}" != "stop" ]] && [[ "${action}" != "remove" ]] && [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]]; then
  >&2 echo "Invalid action: ${action} defined!"
  usage
  exit 1
fi
export action

if [[ $(which jq | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: jq"
  exit 1
fi

if [[ $(which ts | wc -l) == 0 ]]; then
  >&2 echo "Please install required package: moreutils"
  exit 1
fi

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi
anodosysPath=$(cd -P "$( dirname "${scriptName}" )" && pwd)
export anodosysPath

anodosysAppPath="${anodosysPath}/app"
export anodosysAppPath

anodosysConfigurationPath="${anodosysPath}/configuration"
mkdir -p "${anodosysConfigurationPath}"
export anodosysConfigurationPath

anodosysScriptPath="${anodosysPath}/script"
mkdir -p "${anodosysScriptPath}"
export anodosysScriptPath

anodosysExtensionPath="${anodosysPath}/extension"
mkdir -p "${anodosysExtensionPath}"
export anodosysExtensionPath

anodosysExtensions=( $(find "${anodosysExtensionPath}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") )
export anodosysExtensions

if [[ ! -f anodosys.json ]] && { test -f anodosys/anodosys.json; test -f anodosys/ads.json; }; then
  cd anodosys
elif [[ ! -f anodosys.json ]] && { test -f ads/anodosys.json; test -f ads/ads.json; }; then
  cd ads
fi

if [[ ! -f anodosys.json ]] && [[ ! -f ads.json ]]; then
  >&2 echo "Could not find anodosys.json or ads.json in directory: ${PWD}"
  exit 1
fi

currentUser=$(whoami)
currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

anodosysUserPath="${currentUserHome}/.anodosys"
mkdir -p "${anodosysUserPath}"
export anodosysUserPath

anodosysUserVarPath="${anodosysUserPath}/var"
mkdir -p "${anodosysUserVarPath}"
export anodosysUserVarPath

anodosysUserVarConfigurationPath="${anodosysUserVarPath}/configuration"
mkdir -p "${anodosysUserVarConfigurationPath}"
export anodosysUserVarConfigurationPath

configurationFiles=( $(collectConfigurationFiles "${serverName}" "${fileName}") )
configurationFiles=( $(tr ' ' '\n' <<<"${configurationFiles[@]}" | awk '!u[$0]++' | tr '\n' ' ') )
configurationFiles=( $(prepareConfigurationFiles "${configurationFiles[@]}") )
configurationHash=$(for configurationFile in "${configurationFiles[@]}"; do md5sum "${configurationFile}"; done | md5sum | awk '{print $1}')
anodosysConfigurationFile="${anodosysUserVarConfigurationPath}/${configurationHash}.json"
export anodosysConfigurationFile

if [[ ! -f "${anodosysConfigurationFile}" ]]; then
  echo "Creating configuration file at: ${anodosysConfigurationFile}"
  jq -s 'def deepmerge(a;b): reduce b[] as $item (a; reduce ($item | keys_unsorted[]) as $key (.; $item[$key] as $val | ($val | type) as $type | .[$key] = if ($type == "object") then deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val]) elif ($type == "array") then (.[$key] + $val | unique) else $val end)); deepmerge({}; .)' "${configurationFiles[@]}" > "${anodosysConfigurationFile}"
  "${anodosysPath}/app/system/container/configuration.sh"
fi

systemName=$(jq -r '.global .systemName //empty' "${anodosysConfigurationFile}")

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name defined!"
  exit 1
fi
export systemName

if [[ "${action}" != "cmd" ]] && [[ "${action}" != "config" ]]; then
  logName "${systemName}"
fi

setServerConfiguration "${systemName}" "system"

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names defined!"
  exit 1
fi

if [[ "${action}" == "cmd" ]]; then
  shift
  serverName="${1}"
  shift
  userName="${1}"
  shift
  command=( "${@}" )
  "${anodosysPath}/app/server/container/command.sh" -s "${serverName}" -u "${userName}" -c "${command[@]}"
  exit 0
fi

if [[ "${action}" == "config" ]]; then
  cat "${anodosysConfigurationFile}"
  exit 0
fi

if [[ -n "${actionStartScript}" ]]; then
  echo "Action start script: ${actionStartScript}"
  "${actionStartScript}"
fi

if [[ "${action}" == "build" ]] || [[ "${action}" == "rebuild" ]] || [[ "${action}" == "pull" ]] || [[ "${action}" == "install" ]] || [[ "${action}" == "start" ]] || [[ "${action}" == "restart" ]]; then
  # break if any source image does not exists
  "${anodosysPath}/app/system/image/exists.sh" -s -n
fi

if [[ "${action}" == "build" ]]; then
  # break if any target image already exists
  "${anodosysPath}/app/system/image/exists.sh" -t
fi

if [[ "${action}" == "build" ]] || [[ "${action}" == "install" ]]; then
  # break if any container already exists
  "${anodosysPath}/app/system/container/exists.sh"
fi

if [[ "${action}" == "rebuild" ]] || [[ "${action}" == "restart" ]] || [[ "${action}" == "stop" ]] || [[ "${action}" == "remove" ]] || [[ "${action}" == "destroy" ]]; then
  "${anodosysPath}/app/system/container/stop.sh"
fi

if [[ "${action}" == "stop" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

if [[ "${action}" == "rebuild" ]] || [[ "${action}" == "destroy" ]] || [[ "${action}" == "remove" ]]; then
  "${anodosysPath}/app/system/container/remove.sh"
fi

if [[ "${action}" == "rebuild" ]] || [[ "${action}" == "destroy" ]] || [[ "${action}" == "remove" ]]; then
  "${anodosysPath}/app/system/network/remove.sh"
fi

if [[ "${action}" == "remove" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

if [[ "${action}" == "build" ]] || [[ "${action}" == "rebuild" ]] || [[ "${action}" == "install" ]] || [[ "${action}" == "pull" ]]; then
  # pull the source images if available
  "${anodosysPath}/app/system/image/pull.sh" -s
fi

if [[ "${action}" == "start" ]] || [[ "${action}" == "restart" ]] || [[ "${action}" == "pull" ]]; then
  # pull the build images if available
  "${anodosysPath}/app/system/image/pull.sh" -t
fi

if [[ "${action}" == "pull" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

if [[ "${action}" == "rebuild" ]] || [[ "${action}" == "destroy" ]] || [[ "${action}" == "image" ]]; then
  "${anodosysPath}/app/system/image/remove.sh"
fi

if [[ "${action}" == "destroy" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

"${anodosysPath}/app/system/network/create.sh"

if [[ "${action}" == "start" ]] || [[ "${action}" == "restart" ]]; then
  # creates the containers from the build image
  "${anodosysPath}/app/system/container/create.sh" -t
elif [[ "${action}" != "image" ]]; then
  # creates the containers from the source image
  "${anodosysPath}/app/system/container/create.sh" -s
fi

if [[ "${action}" != "image" ]]; then
  "${anodosysPath}/app/system/container/start.sh"
fi

# break if not all containers are running
"${anodosysPath}/app/system/container/running.sh"

if [[ "${action}" == "start" ]] || [[ "${action}" == "restart" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

if [[ "${action}" != "image" ]]; then
  # container provisioning process
  "${anodosysPath}/app/system/container/prepare.sh"
  "${anodosysPath}/app/system/container/install.sh"
  "${anodosysPath}/app/system/container/dismantle.sh"
fi

if [[ "${action}" == "install" ]]; then
  if [[ -n "${actionFinishScript}" ]]; then
    echo "Action start finish: ${actionFinishScript}"
    "${actionFinishScript}"
  fi

  echo "Finished"
  exit 0
fi

# create & push image if requested
"${anodosysPath}/app/system/image/create.sh"
"${anodosysPath}/app/system/image/push.sh"

if [[ -n "${actionFinishScript}" ]]; then
  echo "Action finish script: ${actionFinishScript}"
  "${actionFinishScript}"
fi

echo "Finished"
