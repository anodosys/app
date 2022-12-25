#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

# shellcheck disable=SC2154
if [[ "${#stepScripts[@]}" -eq 0 ]]; then
  >&2 echo "No step scripts defined"
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

declare -A steps
steps["init"]="imageExistsSourceRemote,imagePullSource"
steps["build"]="imageNotExistsTarget,action:rebuild"
steps["rebuild"]="action:erect,action:image,action:push,action:remove"
steps["erect"]="action:source,action:install"
steps["source"]="containerNotExists,imageExistsSource,imagePullSource,networkCreate,containerCreateSource,add"
steps["install"]="containerHost,containerStart,containerRunning,containerPrepare,containerInstall,containerDismantle,start"
steps["image"]="containerExists,containerStop,imageRemoveTargetLocal,imageCreate"
steps["push"]="imageExistsTarget,imageRemoveTargetRemote,imagePush"
steps["prepare"]="imageExistsTargetRemote,imagePullTarget"
steps["run"]="action:create,action:start"
steps["create"]="containerNotExists,imageExistsTarget,imagePullTarget,networkCreate,containerCreateTarget,add"
steps["start"]="containerExists,containerNotRunning,containerHost,containerStart,containerRunning,containerCommencement,containerProduction,containerFinishing,start"
steps["stop"]="containerExists,containerRunning,containerStop,containerNotRunning,stop"
steps["restart"]="action:stop,action:start"
steps["remove"]="containerExists,containerNotRunning,containerRemove,networkRemove,remove"
steps["erase"]="action:stop,action:remove"
steps["clean"]="containerNotExists,imageRemoveTargetLocal"
steps["destroy"]="containerNotExists,imageRemoveSourceLocal,imageRemoveTargetRemote"

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
