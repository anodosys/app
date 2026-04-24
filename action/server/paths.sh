#!/bin/bash -e

if [[ -z "${anodosysAppPath}" ]]; then
  >&2 echo "No anodosys app path defined"
  exit 1
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names defined!"
  exit 1
fi

logDisable

echo "server     | container path                                                         | user            | mode"
echo "---------- | ---------------------------------------------------------------------- | --------------- | ----"
for serverName in "${serverNames[@]}"; do
  "${anodosysAppPath}/server/paths.sh" -s "${serverName}"
done
