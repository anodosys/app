#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No app path specified!"
  exit 1
fi

if [[ -z "${anodosysUserPath}" ]]; then
  >&2 echo "No anodosys user path defined"
  exit 1
fi

if [[ -z "${anodosysConfigurationPath}" ]]; then
  >&2 echo "No configuration path specified!"
  exit 1
fi

if [[ -z "${anodosysUserConfigurationPath}" ]]; then
  >&2 echo "No user configuration path specified!"
  exit 1
fi

if [[ -z "${anodosysUserVarConfigurationPath}" ]]; then
  >&2 echo "No user var configuration path specified!"
  exit 1
fi

if [[ -z "${anodosysScriptPath}" ]]; then
  >&2 echo "No script path specified!"
  exit 1
fi

if [[ -z "${anodosysUserScriptPath}" ]]; then
  >&2 echo "No user script path specified!"
  exit 1
fi

if [[ -z "${anodosysExtensionPath}" ]]; then
  >&2 echo "No extension path specified!"
  exit 1
fi

if [[ -z "${anodosysUserExtensionPath}" ]]; then
  >&2 echo "No user extension path specified!"
  exit 1
fi

if [[ -z "${fileName}" ]]; then
  >&2 echo "No file name specified!"
  exit 1
fi

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
            if test "${valueParts[3]+isset}"; then
              preparedValue="${sourcePath}:${valueParts[1]}:${valueParts[2]}:${valueParts[3]}"
            elif test "${valueParts[2]+isset}"; then
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
  if [[ "${key}" == "beforeImageExistsSourceScript" ]] || [[ "${key}" == "imageExistsSourceScript" ]] || [[ "${key}" == "afterImageExistsSourceScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageExistsTargetScript" ]] || [[ "${key}" == "imageExistsTargetScript" ]] || [[ "${key}" == "afterImageExistsTargetScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageNotExistsTargetScript" ]] || [[ "${key}" == "imageNotExistsTargetScript" ]] || [[ "${key}" == "afterImageNotExistsTargetScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImagePullSourceScript" ]] || [[ "${key}" == "imagePullSourceScript" ]] || [[ "${key}" == "afterImagePullSourceScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImagePullTargetScript" ]] || [[ "${key}" == "imagePullTargetScript" ]] || [[ "${key}" == "afterImagePullTargetScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageCreateScript" ]] || [[ "${key}" == "imageCreateScript" ]] || [[ "${key}" == "afterImageCreateScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImagePushScript" ]] || [[ "${key}" == "imagePushScript" ]] || [[ "${key}" == "afterImagePushScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageRemoveSourceLocalScript" ]] || [[ "${key}" == "imageRemoveSourceLocalScript" ]] || [[ "${key}" == "afterImageRemoveSourceLocalScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageRemoveTargetLocalScript" ]] || [[ "${key}" == "imageRemoveTargetLocalScript" ]] || [[ "${key}" == "afterImageRemoveTargetLocalScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageRemoveSourceRemoteScript" ]] || [[ "${key}" == "imageRemoveSourceRemoteScript" ]] || [[ "${key}" == "afterImageRemoveSourceRemoteScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeImageRemoveTargetRemoteScript" ]] || [[ "${key}" == "imageRemoveTargetRemoteScript" ]] || [[ "${key}" == "afterImageRemoveTargetRemoteScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerConfigurationScript" ]] || [[ "${key}" == "containerConfigurationScript" ]] || [[ "${key}" == "afterContainerConfigurationScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerExistsScript" ]] || [[ "${key}" == "containerExistsScript" ]] || [[ "${key}" == "afterContainerExistsScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerNotExistsScript" ]] || [[ "${key}" == "containerNotExistsScript" ]] || [[ "${key}" == "afterContainerNotExistsScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerCreateSourceScript" ]] || [[ "${key}" == "containerCreateSourceScript" ]] || [[ "${key}" == "afterContainerCreateSourceScript" ]]; then
    canCompletePath=1
  fi
  if [[ "${key}" == "beforeContainerCreateTargetScript" ]] || [[ "${key}" == "containerCreateTargetScript" ]] || [[ "${key}" == "afterContainerCreateTargetScript" ]]; then
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
    eval "value=\"${value}\""
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
          if [[ -f "${anodosysUserConfigurationPath}/${value}" ]]; then
            realpath "${anodosysUserConfigurationPath}/${value}"
            exit 0
          fi
          if [[ -n "${anodosysSharedExtensions}" ]]; then
            for anodosysExtension in "${anodosysSharedExtensions[@]}"; do
              if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/configuration/${value}" ]]; then
                realpath "${anodosysExtensionPath}/${anodosysExtension}/configuration/${value}"
                exit 0
              fi
            done
          fi
          if [[ -n "${anodosysUserExtensions}" ]]; then
            for anodosysExtension in "${anodosysUserExtensions[@]}"; do
              if [[ -f "${anodosysUserExtensionPath}/${anodosysExtension}/configuration/${value}" ]]; then
                realpath "${anodosysUserExtensionPath}/${anodosysExtension}/configuration/${value}"
                exit 0
              fi
            done
          fi
        else
          if [[ -f "${anodosysUserScriptPath}/${value}" ]]; then
            realpath "${anodosysUserScriptPath}/${value}"
            exit 0
          fi
          for anodosysExtension in "${anodosysSharedExtensions[@]}"; do
            if [[ -f "${anodosysExtensionPath}/${anodosysExtension}/script/${value}" ]]; then
              realpath "${anodosysExtensionPath}/${anodosysExtension}/script/${value}"
              exit 0
            fi
          done
          if [[ -f "${anodosysScriptPath}/${value}" ]]; then
            realpath "${anodosysScriptPath}/${value}"
            exit 0
          fi
          for anodosysExtension in "${anodosysUserExtensions[@]}"; do
            if [[ -f "${anodosysUserExtensionPath}/${anodosysExtension}/script/${value}" ]]; then
              realpath "${anodosysUserExtensionPath}/${anodosysExtension}/script/${value}"
              exit 0
            fi
          done
          if [[ -f "${anodosysAppPath}/${value}" ]]; then
            realpath "${anodosysAppPath}/${value}"
            exit 0
          fi
        fi
      fi
      echo "${sourceFilePath}/${value}"
      exit 0
    fi
  fi

  echo "${value}"
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

# shellcheck disable=SC2034
typeset -fx setServerConfiguration

configurationFileName=$(realpath "${fileName}")
export configurationFileName

configurationFiles=( $(collectConfigurationFiles "${configurationFileName}") )
configurationFiles=( $(tr ' ' '\n' <<<"${configurationFiles[@]}" | awk '!u[$0]++' | tr '\n' ' ') )
configurationFiles=( $(prepareConfigurationFiles "${configurationFiles[@]}") )
configurationHash=$(for configurationFile in "${configurationFiles[@]}"; do md5sum "${configurationFile}"; done | md5sum | awk '{print $1}')
anodosysConfigurationFile="${anodosysUserVarConfigurationPath}/${configurationHash}.json"
export anodosysConfigurationFile

if [[ ! -f "${anodosysConfigurationFile}" ]]; then
  echo "Creating configuration file at: ${anodosysConfigurationFile}"
  jq -s 'def deepmerge(a;b): reduce b[] as $item (a; reduce ($item | keys_unsorted[]) as $key (.; $item[$key] as $val | ($val | type) as $type | .[$key] = if ($type == "object") then deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val]) elif ($type == "array") then (.[$key] + $val | unique) else $val end)); deepmerge({}; .)' "${configurationFiles[@]}" > "${anodosysConfigurationFile}"
  "${anodosysAppPath}/system/container/configuration.sh"
fi
