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
steps["host"]="containerHost"
steps["init"]="imageExistsSourceRemote,imagePullSource"
steps["build"]="imageNotExistsTarget,action:rebuild"
steps["rebuild"]="action:shell,action:push,action:remove"
steps["shell"]="action:rise,action:image"
steps["rise"]="action:source,action:install"
steps["source"]="containerNotExists,containerHost,imageExistsSource,imagePullSource,networkCreate,containerCreateSource,add"
steps["install"]="action:up,containerPrepare,containerInstall,containerDismantle,start"
steps["image"]="action:stop,imageRemoveTargetLocal,imageCreate"
steps["push"]="imageExistsTarget,imageRemoveTargetRemote,imagePush"
steps["prepare"]="imageExistsTargetRemote,imagePullTarget"
steps["run"]="action:create,action:start"
steps["create"]="containerNotExists,containerHost,imageExistsTarget,imagePullTarget,networkCreate,containerCreateTarget,add"
steps["up"]="containerExists,containerNotRunning,containerHost,networkCreate,containerStart,containerRunning"
steps["start"]="action:up,containerCommencement,containerProduction,containerFinishing,start"
steps["stop"]="containerExists,containerStop,containerNotRunning,stop"
steps["restart"]="action:stop,action:start"
steps["remove"]="containerExists,containerNotRunning,containerRemove,networkRemove,remove"
steps["clean"]="containerNotExists,imageRemoveTargetLocal"
steps["purge"]="action:stop,action:remove"
steps["erase"]="action:purge,action:clean"
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
        action="steps"
        exit 1
      fi
    else
      >&2 echo "No script found to execute step: ${actionStep}"
      action="steps"
      exit 1
    fi
  done
else
  >&2 echo "No steps found for action: ${action}"
  action="steps"
  usage
  exit 1
fi

if [[ -n "${actionFinishScript}" ]]; then
  echo "Action finish script: ${actionFinishScript}"
  "${actionFinishScript}"
fi
