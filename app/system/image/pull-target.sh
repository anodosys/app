#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

echo "- Image pull target -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImagePullTargetScript}" ]]; then
  echo "Before image pull target script: ${beforeImagePullTargetScript}"
  "${beforeImagePullTargetScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# pull the source images if available
for serverName in "${serverNames[@]}"; do
  if [[ -n "${server}" ]] && [[ "${server}" != "${serverName}" ]]; then
    continue
  fi

  imageScript="${PWD}/${serverName}/image/pull-target.sh"
  if [[ -f "${imageScript}" ]]; then
    echo "[${serverName}] Pulling target image of server: ${serverName} with custom script: ${imageScript}"
    "${imageScript}"
  else
    "${currentPath}/../../server/image/pull-target.sh" -s "${serverName}"
  fi
done

if [[ -n "${afterImagePullTargetScript}" ]]; then
  echo "After image pull target script: ${afterImagePullTargetScript}"
  "${afterImagePullTargetScript}"
fi
