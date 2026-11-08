#!/bin/bash -e

# Prints the Anodosys logo, sourced by anodosys.sh (callers decide when and where to)

if [[ -z "${anodosysPath}" ]]; then
  >&2 echo "No anodosys path defined"
  exit 1
fi

bannerAccent=
bannerDim=
bannerReset=
if [[ -z "${NO_COLOR}" ]] && [[ "${TERM}" != "dumb" ]]; then
  bannerAccent=$'\033[38;5;37m'
  bannerDim=$'\033[2m'
  bannerReset=$'\033[0m'
fi

# An installed release lives in a directory named after its version, e.g. /usr/local/lib/anodosys/2.8.0
bannerVersion=$(basename "${anodosysPath}")
if [[ ! "${bannerVersion}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  bannerVersion=
fi

a="${bannerAccent}"
r="${bannerReset}"
cat << EOF

      ${a}▄▄▄▄▄▄▄▄▄▄${r}
      ${a}██████████${r}                          █
      ${a}▀▀▀▀▀▀▀▀▀▀${r}     ▀▀▀▄ █▀▀▀▄ ▄▀▀▀▄ ▄▀▀▀█ ▄▀▀▀▄ ${a}▄▀▀▀▀ █   █ ▄▀▀▀▀${r}
   ██████████       ▄▀▀▀█ █   █ █   █ █   █ █   █ ${a} ▀▀▀▄ █   █  ▀▀▀▄${r}
   ██████████       ▀▄▄▄█ █   █ ▀▄▄▄▀ ▀▄▄▄█ ▀▄▄▄▀ ${a}▄▄▄▄▀  ▀▀▀█ ▄▄▄▄▀${r}
▄▄▄▄▄▄▄▄▄▄                                              ${a}▄▄▄▄▀${r}
██████████
▀▀▀▀▀▀▀▀▀▀          ${bannerDim}step pipelines across docker containers${bannerVersion:+ · ${bannerVersion}}${r}

EOF
unset a r bannerAccent bannerDim bannerReset bannerVersion
