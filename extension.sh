#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} <ACTION> <NAME>

ACTION:
  add     Add extension
  update  Update extension
  remove  Remove extension
  reset   Reset extension

Example: ${scriptName} add example git git@bitbucket.org:org/example.git
EOF
}

usageAdd()
{
cat >&2 << EOF

usage: ${scriptName} ${action} <NAME> <TYPE> <URL>

Example: ${scriptName} ${action} example git git@bitbucket.org:org/example.git
EOF
}

usageAddName()
{
cat >&2 << EOF

usage: ${scriptName} ${action} ${extensionName} <TYPE> <URL>

Example: ${scriptName} ${action} ${extensionName} git git@bitbucket.org:org/example.git
EOF
}

usageAddNameGit()
{
cat >&2 << EOF

usage: ${scriptName} ${action} ${extensionName} ${type} <URL>

Example: ${scriptName} ${action} ${extensionName} ${type} git@bitbucket.org:org/example.git
EOF
}

scriptName="${BASH_SOURCE[0]}"
if [[ -L "${scriptName}" ]]; then
  scriptName=$(readlink -f "${scriptName}")
fi

anodosysPath=$(cd -P "$( dirname "${scriptName}" )" && pwd)

anodosysExtensionPath="${anodosysPath}/extension"

currentUser=$(whoami)
currentUserHome=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

anodosysUserPath="${currentUserHome}/.anodosys"
mkdir -p "${anodosysUserPath}"

anodosysUserConfigurationPath="${anodosysUserPath}/configuration"
mkdir -p "${anodosysUserConfigurationPath}"

anodosysUserExtensionPath="${anodosysUserPath}/extension"
mkdir -p "${anodosysUserExtensionPath}"

anodosysUserHostPath="${anodosysUserPath}/host"
mkdir -p "${anodosysUserHostPath}"

anodosysUserScriptPath="${anodosysUserPath}/script"
mkdir -p "${anodosysUserScriptPath}"

anodosysUserVarPath="${anodosysUserPath}/var"
mkdir -p "${anodosysUserVarPath}"

anodosysUserVarExtensionPath="${anodosysUserVarPath}/extension"
mkdir -p "${anodosysUserVarExtensionPath}"

action="${1}"

if [[ -z "${action}" ]]; then
  >&2 echo "No action defined!"
  usage
  exit 1
fi

if [[ "${action}" == "help" ]]; then
  usage
  exit 1
fi

if [[ "${action}" != "add" ]] && [[ "${action}" != "update" ]] && [[ "${action}" != "remove" ]] && [[ "${action}" != "reset" ]]; then
  >&2 echo "Invalid action: ${action} defined!"
  usage
  exit 1
fi

extensionName="${2}"

if [[ -z "${extensionName}" ]]; then
  >&2 echo "No extension name defined!"
  usageAdd
  exit 1
fi

if [[ "${extensionName}" == "help" ]]; then
  usageAdd
  exit 1
fi

if [[ "${action}" == "update" ]]; then
  if [[ "${currentUser}" == "root" ]] && [[ ! -d "${anodosysExtensionPath}/${extensionName}" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysExtensionPath}/${extensionName}"
    exit 1
  elif [[ "${currentUser}" != "root" ]] && [[ ! -d "${anodosysUserExtensionPath}/${extensionName}" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysUserExtensionPath}/${extensionName}"
    exit 1
  fi

  if [[ -d "${anodosysUserVarExtensionPath}/${extensionName}/.git" ]]; then
    cd "${anodosysUserVarExtensionPath}/${extensionName}"
    git pull

    if [[ "${currentUser}" == "root" ]]; then
      rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysExtensionPath}/${extensionName}/"
    else
      rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysUserExtensionPath}/${extensionName}/"
    fi
  else
    >&2 echo "Could not determine extension type"
    exit 1
  fi

  exit 0
fi

if [[ "${action}" == "remove" ]]; then
  if [[ "${currentUser}" == "root" ]] && [[ ! -d "${anodosysExtensionPath}/${extensionName}" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysExtensionPath}/${extensionName}"
    exit 1
  elif [[ "${currentUser}" != "root" ]] && [[ ! -d "${anodosysUserExtensionPath}/${extensionName}" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysUserExtensionPath}/${extensionName}"
    exit 1
  fi

  if [[ "${currentUser}" == "root" ]]; then
    # shellcheck disable=SC2115
    rm -rf "${anodosysPath}/${extensionName}"
  else
    # shellcheck disable=SC2115
    rm -rf "${anodosysUserExtensionPath}/${extensionName}"
  fi

  # shellcheck disable=SC2115
  rm -rf "${anodosysUserVarExtensionPath}/${extensionName}"

  exit 0
fi

if [[ "${action}" == "add" ]]; then
  if [[ -d "${anodosysPath}/${extensionName}" ]]; then
    >&2 echo "Extension already added in: ${anodosysPath}/${extensionName}"
    exit 1
  fi

  if [[ -d "${anodosysUserExtensionPath}/${extensionName}" ]]; then
    >&2 echo "Extension already added in: ${anodosysUserExtensionPath}/${extensionName}"
    exit 1
  fi
fi

type="${3}"

if [[ -z "${type}" ]]; then
  >&2 echo "No type defined!"
  usageAddName
  exit 1
fi

if [[ "${type}" == "help" ]]; then
  usageAddName
  exit 1
fi

if [[ "${type}" != "git" ]]; then
  >&2 echo "Invalid type: ${action} defined!"
  usageAddName
  exit 1
fi

if [[ "${type}" == "git" ]]; then
  if [[ $(which git | wc -l) == 0 ]]; then
    >&2 echo "Please install required package: git"
    exit 1
  fi

  url="${4}"

  if [[ -z "${url}" ]]; then
    >&2 echo "No url defined!"
    usageAddNameGit
    exit 1
  fi

  if [[ "${url}" == "help" ]]; then
    usageAddNameGit
    exit 1
  fi

  cd "${anodosysUserVarExtensionPath}"

  if [[ -d "${extensionName}" ]]; then
    cd "${extensionName}"
    git pull
  else
    git clone "${url}" "${extensionName}"
  fi

  if [[ "${currentUser}" == "root" ]]; then
    mkdir -p "${anodosysPath}/${extensionName}"
    rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysPath}/${extensionName}/"
  else
    mkdir -p "${anodosysUserExtensionPath}/${extensionName}"
    rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysUserExtensionPath}/${extensionName}/"
  fi
fi
