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
steps["build"]="imageNotExistsTarget,action:install,action:image,action:remove,action:push"
steps["rebuild"]="containerNotExists,action:install,action:image,action:remove,action:push"
steps["install"]="containerNotExists,imageExistsSource,imagePullSource,networkCreate,containerCreateSource,containerStart,containerPrepare,containerInstall,containerDismantle"
steps["image"]="containerExists,containerStop,imageRemoveTargetLocal,imageCreate"
steps["push"]="imageExistsTarget,imageRemoveTargetRemote,imagePush"
steps["prepare"]="imageExistsTargetRemote,imagePullTarget"
steps["create"]="containerNotExists,imageExistsTarget,imagePullTarget,networkCreate,containerCreateTarget,add"
steps["start"]="containerExists,containerNotRunning,containerStart,containerRunning,containerCommencement,containerProduction,containerFinishing,start"
steps["stop"]="containerExists,containerRunning,containerStop,containerNotRunning,stop"
steps["restart"]="action:stop,action:start"
steps["remove"]="containerExists,containerNotRunning,containerRemove,networkRemove,remove"
steps["clean"]="containerStop,containerRemove,networkRemove,imageRemoveTargetLocal"
steps["destroy"]="action:clean,imageRemoveSourceLocal,imageRemoveTargetRemote"

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
