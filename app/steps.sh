#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

getActionSteps()
{
  local stepAction="${1}"
  local completeStepActionSteps
  local stepActionSteps
  local stepActionStep
  local stepActionStepAction
  local stepActionStepActionSteps
  local stepActionStepActionStep

  completeStepActionSteps=( )

  if test "${steps["${stepAction}"]+isset}"; then
    readarray -d , -t stepActionSteps < <(printf '%s' "${steps["${stepAction}"]}")

    for stepActionStep in "${stepActionSteps[@]}"; do
      if [[ "${stepActionStep:0:7}" == "action:" ]]; then
        stepActionStepAction="${stepActionStep:7}"
        stepActionStepActionSteps=( $(getActionSteps "${stepActionStepAction}") )
        for stepActionStepActionStep in "${stepActionStepActionSteps[@]}"; do
          completeStepActionSteps+=( "${stepActionStepActionStep}" )
        done
      else
        completeStepActionSteps+=( "${stepActionStep}" )
      fi
    done
  fi

  echo "${completeStepActionSteps[@]}"
}

declare -A stepScripts
stepScripts["containerCreateSource"]="${anodosysAppPath}/system/container/create-source.sh"
stepScripts["containerCreateTarget"]="${anodosysAppPath}/system/container/create-target.sh"
stepScripts["containerDismantle"]="${anodosysAppPath}/system/container/dismantle.sh"
stepScripts["containerExists"]="${anodosysAppPath}/system/container/exists.sh"
stepScripts["containerInstall"]="${anodosysAppPath}/system/container/install.sh"
stepScripts["containerNotExists"]="${anodosysAppPath}/system/container/not-exists.sh"
stepScripts["containerPrepare"]="${anodosysAppPath}/system/container/prepare.sh"
stepScripts["containerRemove"]="${anodosysAppPath}/system/container/remove.sh"
stepScripts["containerRunning"]="${anodosysAppPath}/system/container/running.sh"
stepScripts["containerStart"]="${anodosysAppPath}/system/container/start.sh"
stepScripts["containerStop"]="${anodosysAppPath}/system/container/stop.sh"
stepScripts["imageCreate"]="${anodosysAppPath}/system/image/create.sh"
stepScripts["imageExistsSource"]="${anodosysAppPath}/system/image/exists-source.sh"
stepScripts["imageExistsSourceRemote"]="${anodosysAppPath}/system/image/exists-source-remote.sh"
stepScripts["imageExistsTarget"]="${anodosysAppPath}/system/image/exists-target.sh"
stepScripts["imageExistsTargetRemote"]="${anodosysAppPath}/system/image/exists-target-remote.sh"
stepScripts["imageNotExistsTarget"]="${anodosysAppPath}/system/image/not-exists-target.sh"
stepScripts["imagePullSource"]="${anodosysAppPath}/system/image/pull-source.sh"
stepScripts["imagePullTarget"]="${anodosysAppPath}/system/image/pull-target.sh"
stepScripts["imagePush"]="${anodosysAppPath}/system/image/push.sh"
stepScripts["imageRemoveSourceLocal"]="${anodosysAppPath}/system/image/remove-source-local.sh"
stepScripts["imageRemoveTargetLocal"]="${anodosysAppPath}/system/image/remove-target-local.sh"
stepScripts["imageRemoveTargetRemote"]="${anodosysAppPath}/system/image/remove-target-remote.sh"
stepScripts["networkCreate"]="${anodosysAppPath}/system/network/create.sh"
stepScripts["networkRemove"]="${anodosysAppPath}/system/network/remove.sh"
stepScripts["systemAdd"]="${anodosysAppPath}/system/add.sh"
stepScripts["systemRemove"]="${anodosysAppPath}/system/remove.sh"
stepScripts["systemStart"]="${anodosysAppPath}/system/start.sh"
stepScripts["systemStop"]="${anodosysAppPath}/system/stop.sh"

declare -A steps
steps["build"]="imageNotExistsTarget,action:install,imageRemoveTargetLocal,action:image,action:remove,imageRemoveTargetRemote,action:push"
steps["rebuild"]="action:remove,action:install,imageRemoveTargetLocal,action:image,action:remove,imageRemoveTargetRemote,action:push"
steps["pull"]="imageExistsSourceRemote,imagePullSource,imageExistsTargetRemote,imagePullTarget"
steps["install"]="containerNotExists,imageExistsSource,imagePullSource,networkCreate,containerCreateSource,containerStart,containerPrepare,containerInstall,containerDismantle"
steps["image"]="containerExists,containerStop,imageCreate"
steps["push"]="imageExistsTarget,imagePush"
steps["clean"]="action:remove,imageRemoveTargetLocal"
steps["destroy"]="action:clean,imageRemoveSourceLocal,imageRemoveTargetRemote"
steps["create"]="containerNotExists,imageExistsTarget,imagePullTarget,systemAdd,networkCreate,containerCreateTarget"
steps["start"]="containerExists,containerStart,containerRunning,systemStart"
steps["restart"]="action:stop,action:start"
steps["stop"]="containerStop,systemStop"
steps["remove"]="containerStop,containerRemove,networkRemove,systemRemove"

if [[ -n "${actionStartScript}" ]]; then
  echo "Action start script: ${actionStartScript}"
  "${actionStartScript}"
fi

actionSteps=( $(getActionSteps "${action}") )

if [[ "${#actionSteps[@]}" -gt 0 ]]; then
  for actionStep in "${actionSteps[@]}"; do
    if test "${stepScripts["${actionStep}"]+isset}"; then
      stepScript="${stepScripts["${actionStep}"]}"
      if [[ -f "${stepScript}" ]]; then
        "${stepScript}"
      else
        >&2 echo "Step script not found at: ${stepScript}"
        exit 1
      fi
    else
      >&2 echo "No script found to execute step: ${actionStep}"
      exit 1
    fi
  done
else
  >&2 echo "No steps found for action: ${action}"
  usage
  exit 1
fi

if [[ -n "${actionFinishScript}" ]]; then
  echo "Action finish script: ${actionFinishScript}"
  "${actionFinishScript}"
fi
