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

anodosysPath=$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

anodosysExtensionPath="${anodosysPath}/extension"
sudo mkdir -p "${anodosysExtensionPath}"

anodosysUserPath=$(realpath "~/.anodosys")
mkdir -p "${anodosysUserPath}"
export anodosysUserPath

anodosysUserVarPath="${anodosysUserPath}/var"
mkdir -p "${anodosysUserVarPath}"
export anodosysUserVarPath

anodosysUserVarExtensionPath="${anodosysUserVarPath}/extension"
mkdir -p "${anodosysUserVarExtensionPath}"
export anodosysUserVarExtensionPath

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

if [[ "${action}" != "add" ]] && [[ "${action}" != "update" ]] && [[ "${action}" != "remove" ]]; then
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
  if [[ ! -d "${anodosysExtensionPath}/${extensionName}/" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysExtensionPath}/${extensionName}/"
    exit 1
  fi

  if [[ -d "${anodosysExtensionPath}/${extensionName}/.git" ]]; then
    cd "${anodosysExtensionPath}/${extensionName}"

    git pull

    cd "${anodosysPath}"

    sudo rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysExtensionPath}/${extensionName}/"
  else
    >&2 echo "Could not determine extension type"
    exit 1
  fi

  exit 0
fi

if [[ "${action}" == "remove" ]]; then
  if [[ ! -d "${anodosysExtensionPath}/${extensionName}/" ]]; then
    >&2 echo "Extension does not exist in: ${anodosysExtensionPath}/${extensionName}/"
    exit 1
  fi

  sudo rm -rf "${anodosysExtensionPath:?}/${extensionName}/"
  sudo rm -rf "${anodosysUserVarExtensionPath:?}/${extensionName}/"
  exit 0
fi

if [[ -d "${anodosysExtensionPath}/${extensionName}/" ]]; then
  >&2 echo "Extension already added in: ${anodosysExtensionPath}/${extensionName}/"
  exit 1
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

  cd "${anodosysPath}"

  sudo mkdir -p "${anodosysExtensionPath}/${extensionName}"
  sudo rsync --exclude '.git/' --exclude '.gitignore' --recursive --checksum --executability --no-owner --no-group --delete --force --verbose "${anodosysUserVarExtensionPath}/${extensionName}/" "${anodosysExtensionPath}/${extensionName}/"
fi
