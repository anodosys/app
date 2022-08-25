#!/bin/bash -e

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
  -l  Length of server name
  -m  Mode, default: all

Example: ${scriptName} -s web -l 10
EOF
}

trim()
{
  echo -n "$1" | xargs
}

serverName=
length=
mode=
times=0

while getopts hs:l:m:t? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) serverName=$(trim "$OPTARG");;
    l) length=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    t) times=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${serverName}" ]]; then
  >&2 echo "No server name specified!"
  usage
  exit 1
fi

if [[ -z "${mode}" ]]; then
  mode="container"
fi

setServerConfiguration "${systemName}" "${serverName}"

containerName="${systemName}_${serverName}"

printf "%-${length}s" "${containerName}"

echo -n " | "

if [[ "${mode}" == "image" ]] || [[ "${mode}" == "remote" ]]; then
  if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    if [[ "${times}" == 1 ]]; then
      printf '%-19s' "$(imageTime "${imageName}" "${imageTag}")"
    else
      printf '%-19s' "$(duration "$(imageTime "${imageName}" "${imageTag}" "%s")")"
    fi
  else
    printf '%-19s' ""
  fi
  echo -n " | "
fi

if [[ "${mode}" == "remote" ]]; then
  if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ -n "${repositoryUserName}" ]] && [[ -n "${repositoryPassword}" ]]; then
    if [[ "${times}" == 1 ]]; then
      printf '%-19s' "$(imageTimeRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}")"
    else
      printf '%-19s' "$(duration "$(imageTimeRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}" "%s")")"
    fi
  else
    printf '%-19s' ""
  fi
  echo -n " | "
fi

if [[ -n "${buildImageName}" ]]; then
  imageName="${buildImageName}"
fi

if [[ -n "${buildImageTag}" ]]; then
  imageTag="${buildImageTag}"
fi

if [[ "${mode}" == "image" ]] || [[ "${mode}" == "remote" ]]; then
  if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ $(imageExists "${imageName}" "${imageTag}") == 1 ]]; then
    if [[ "${times}" == 1 ]]; then
      printf '%-19s' "$(imageTime "${imageName}" "${imageTag}")"
    else
      printf '%-19s' "$(duration "$(imageTime "${imageName}" "${imageTag}" "%s")")"
    fi
  else
    printf '%-19s' ""
  fi
  echo -n " | "
fi

if [[ "${mode}" == "remote" ]]; then
  if [[ -n "${imageName}" ]] && [[ -n "${imageTag}" ]] && [[ -n "${repositoryUserName}" ]] && [[ -n "${repositoryPassword}" ]]; then
    if [[ "${times}" == 1 ]]; then
      printf '%-19s' "$(imageTimeRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}")"
    else
      printf '%-19s' "$(duration "$(imageTimeRemote "${imageName}" "${imageTag}" "${repositoryUserName}" "${repositoryPassword}" "%s")")"
    fi
  else
    printf '%-19s' ""
  fi
  echo -n " | "
fi

if [[ "${times}" == 1 ]]; then
  printf '%-19s' "$(containerCreateTime "${containerName}")"
else
  printf '%-19s' "$(duration "$(containerCreateTime "${containerName}" "%s")")"
fi
echo -n " | "

if [[ "${times}" == 1 ]]; then
  printf '%-19s' "$(containerStartTime "${containerName}")"
else
  printf '%-19s' "$(duration "$(containerStartTime "${containerName}" "%s")")"
fi
echo -n " | "

printf '%-15s' "$(containerIp "${containerName}")"
echo -n " | "

if [[ $(containerRunning "${containerName}") == 1 ]]; then
  portList=( $(containerPortHostList "${containerName}") )
  ports=${portList[*]// /,}
  printf '%-15s' "${ports}"
else
  printf '%-15s' ""
fi

echo ""
