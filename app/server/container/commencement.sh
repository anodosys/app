#!/bin/bash -e

if [[ -z "${anodosysUserVarPath}" ]]; then
  >&2 echo "No anodosys user var path specified!"
  exit 1
fi

if [[ -z "${systemName}" ]]; then
  >&2 echo "No system name specified!"
  exit 1
fi

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  Server name

Example: ${scriptName} -s web
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=

while getopts hs:? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

logName "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

if [[ -f "${anodosysUserVarPath}/commencement/${containerName}" ]]; then
  echo "Commencement already processed"
  exit 0
fi

setServerConfiguration "${systemName}" "${serverName}"

if [[ -n "${beforeContainerCommencementScript}" ]]; then
  echo "Before container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${beforeContainerCommencementParameters}" ]]; then
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${beforeContainerCommencementParameters[@]}"
  else
    "${beforeContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

if [[ -n "${containerCommencementScript}" ]]; then
  echo "Container commencement script: ${beforeContainerCommencementScript}"
  if [[ -n "${containerCommencementParameters}" ]]; then
    "${containerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${containerCommencementParameters[@]}"
  else
    "${containerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
elif [[ -n "${containerCommencement}" ]]; then
  containerCommand "${containerName}" "${containerCommencement}"
else
  echo "Nothing to commence"
fi

if [[ -n "${afterContainerCommencementScript}" ]]; then
  echo "After container commencement script: ${afterContainerCommencementScript}"
  if [[ -n "${afterContainerCommencementParameters}" ]]; then
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}" \
      "${afterContainerCommencementParameters[@]}"
  else
    "${afterContainerCommencementScript}" \
      --systemName "${systemName}" \
      --serverName "${serverName}" \
      --containerName "${containerName}"
  fi
fi

mkdir -p "${anodosysUserVarPath}/commencement"
touch "${anodosysUserVarPath}/commencement/${containerName}"
