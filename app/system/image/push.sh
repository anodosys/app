#!/bin/bash -e

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

setServerConfiguration "${systemName}" "system"

# possible upload of images
echo "- Image push -" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ -n "${beforeImagePushScript}" ]]; then
  echo "Before image push script: ${beforeImagePushScript}"
  "${beforeImagePushScript}"
fi

if [[ -z "${serverNames}" ]]; then
  >&2 echo "No server names specified!"
  exit 1
fi

currentPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

for serverName in "${serverNames[@]}"; do
  imageScript="${PWD}/${serverName}/image/push.sh"
  if [[ -f "${imageScript}" ]]; then
    echo "[${serverName}] Pushing image of server: ${serverName} with custom script: ${imageScript}"
    "${imageScript}"
  else
    "${currentPath}/../../server/image/push.sh" -s "${serverName}"
  fi
done

if [[ -n "${afterImagePushScript}" ]]; then
  echo "After image push script: ${afterImagePushScript}"
  "${afterImagePushScript}"
fi
