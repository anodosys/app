#!/bin/bash -e

containerPath()
{
  local containerName="${1}"
  local containerPath="${2}"
  local accessUser="${3}"
  local mode="${4}"
  local accessRights="${5}"
  local missingMode="${6}"
  local accessPrefix
  local accessName
  local accessRight
  local containerUserId
  local containerUserName
  local containerAccessUser
  local containerPathGroupNames
  local containerPathGroupName

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ -n "${containerPath}" ]]; then
      if [[ $(containerCommandQuiet "${containerName}" "[[ -e ${containerPath} ]] && echo \"true\" || echo \"false\"") == "false" ]]; then
        if [[ "${missingMode}" == "f" ]]; then
          echo "Creating file at container path: ${containerPath}"
          containerCommand "${containerName}" "touch ${containerPath}"
        elif [[ "${missingMode}" == "d" ]]; then
          echo "Creating directory at container path: ${containerPath}"
          containerCommand "${containerName}" "mkdir -p ${containerPath}"
        fi
      fi

      if [[ $(containerCommandQuiet "${containerName}" "[[ -e ${containerPath} ]] && echo \"true\" || echo \"false\"") == "true" ]]; then
        if [[ -n "${accessRights}" ]] && [[ "${accessRights}" != "-" ]]; then
          echo "Setting access rights ${accessRights} to container path: ${containerPath}"
          containerCommand "${containerName}" "[[ -e ${containerPath} ]] && chmod ${accessRights} ${containerPath} || echo \"Path not available\""
        fi

        containerPathGroup "${containerName}" "${containerPath}"
        containerPathUser "${containerName}" "${containerPath}"

        if [[ "${accessUser}" == "local" ]] || [[ "${accessUser}" == "me" ]]; then
          containerPathLocalUser "${containerName}" "${containerPath}"
        fi

        containerUserId=$(containerCommandQuiet "${containerName}" "stat -L -c \"%u\" ${containerPath}")
        containerUserName=$(containerCommandQuiet "${containerName}" "getent passwd ${containerUserId} | cat" | tr ':' ' ' | awk '{print $1}')
        containerUserName=$(prepareValue "${containerUserName}")

        if [[ "${containerUserName}" != "${accessUser}" ]]; then
          containerPathUserGroup "${containerName}" "${containerPath}" "${accessUser}"
        else
          echo "No different user for container path: ${containerPath}"
        fi

        if [[ "${containerUserName}" == "${accessUser}" ]]; then
          accessPrefix="u"
          accessName="user"
        else
          accessPrefix="g"
          accessName="group"
        fi

        if [[ "${mode}" == "r" ]] || [[ "${mode}" == "rr" ]]; then
          if [[ "${mode}" == "r" ]]; then
            echo "Adding ${accessName} read access rights to container path: ${containerPath}"
            containerCommand "${containerName}" "chmod ${accessPrefix}+r ${containerPath}"
          else
            echo "Adding ${accessName} read access rights to container path: ${containerPath} recursively"
            containerCommand "${containerName}" "chmod -R ${accessPrefix}+r ${containerPath}"
            if [[ "${accessUser}" == "local" ]] || [[ "${accessUser}" == "me" ]]; then
              userId="${UID}"
              containerAccessUser=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | tr ':' ' ' | awk '{print \$1}'")
              containerAccessUser=$(prepareValue "${containerAccessUser}")
            else
              containerAccessUser="${accessUser}"
            fi
            containerPathGroupNames=( $(containerCommandQuiet "${containerName}" "find \"${containerPath}\" ! -user \"${containerAccessUser}\" -exec stat -c \"%G\" {} \; | sort -u | grep -vw 0 | cat") )
            for containerPathGroupName in "${containerPathGroupNames[@]}"; do
              containerUserGroup "${containerName}" "${accessUser}" "${containerPathGroupName}"
            done
          fi
          accessRights=$(containerCommandQuiet "${containerName}" "stat -L -c \"%a\" ${containerPath}")
          if [[ "${containerUserName}" == "${accessUser}" ]]; then
            accessRight="${accessRights:0:1}"
          else
            accessRight="${accessRights:1:1}"
          fi
          if [[ "${accessRight}" == 4 ]] || [[ "${accessRight}" == 5 ]] || [[ "${accessRight}" == 6 ]] || [[ "${accessRight}" == 7 ]]; then
            echo "Successfully added ${accessName} read access rights to container path: ${containerPath}" | sed $'s,.*,\e[1;36m&\e[m,'
          else
            >&2 echo "Could not add ${accessName} read access rights to container path: ${containerPath}"
            exit 1
          fi
        elif [[ "${mode}" == "w" ]] || [[ "${mode}" == "wr" ]]; then
          if [[ "${mode}" == "w" ]]; then
            echo "Adding ${accessName} write access rights to container path: ${containerPath}"
            containerCommand "${containerName}" "chmod ${accessPrefix}+w ${containerPath}"
          else
            echo "Adding ${accessName} write access rights to container path: ${containerPath} recursively"
            containerCommand "${containerName}" "chmod -R ${accessPrefix}+w ${containerPath}"
            if [[ "${accessUser}" == "local" ]] || [[ "${accessUser}" == "me" ]]; then
              userId="${UID}"
              containerAccessUser=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | tr ':' ' ' | awk '{print \$1}'")
              containerAccessUser=$(prepareValue "${containerAccessUser}")
            else
              containerAccessUser="${accessUser}"
            fi
            containerPathGroupNames=( $(containerCommandQuiet "${containerName}" "find \"${containerPath}\" ! -user \"${containerAccessUser}\" -exec stat -c \"%G\" {} \; | sort -u | grep -vw 0 | cat") )
            for containerPathGroupName in "${containerPathGroupNames[@]}"; do
              containerUserGroup "${containerName}" "${containerAccessUser}" "${containerPathGroupName}"
            done
          fi
          accessRights=$(containerCommandQuiet "${containerName}" "stat -L -c \"%a\" ${containerPath}")
          if [[ "${containerUserName}" == "${accessUser}" ]]; then
            accessRight="${accessRights:0:1}"
          else
            accessRight="${accessRights:1:1}"
          fi
          if [[ "${accessRight}" == 2 ]] || [[ "${accessRight}" == 3 ]] || [[ "${accessRight}" == 6 ]] || [[ "${accessRight}" == 7 ]]; then
            echo "Successfully added ${accessName} write access rights to container path: ${containerPath}" | sed $'s,.*,\e[1;36m&\e[m,'
          else
            >&2 echo "Could not add ${accessName} access rights to container path: ${containerPath}"
            exit 1
          fi
        elif [[ "${mode}" == "x" ]] || [[ "${mode}" == "xr" ]]; then
          if [[ "${mode}" == "x" ]]; then
            echo "Adding ${accessName} execution access rights to container path: ${containerPath}"
            containerCommand "${containerName}" "chmod ${accessPrefix}+x ${containerPath}"
          else
            echo "Adding ${accessName} execution access rights to container path: ${containerPath} recursively"
            containerCommand "${containerName}" "chmod -R ${accessPrefix}+x ${containerPath}"
          fi
          accessRights=$(containerCommandQuiet "${containerName}" "stat -L -c \"%a\" ${containerPath}")
          if [[ "${containerUserName}" == "${accessUser}" ]]; then
            accessRight="${accessRights:0:1}"
          else
            accessRight="${accessRights:1:1}"
          fi
          if [[ "${accessRight}" == 1 ]] || [[ "${accessRight}" == 3 ]] || [[ "${accessRight}" == 5 ]] || [[ "${accessRight}" == 7 ]]; then
            echo "Successfully added ${accessName} execution access rights to container path: ${containerPath}" | sed $'s,.*,\e[1;36m&\e[m,'
          else
            >&2 echo "Could not add ${accessName} execution access rights to container path: ${containerPath} to: ${accessRights}"
            exit 1
          fi
        elif [[ "${mode}" == "o" ]] || [[ "${mode}" == "or" ]]; then
          if [[ "${mode}" == "o" ]]; then
            echo "Changing user of container path: ${containerPath} to: ${accessUser}"
            containerCommand "${containerName}" "chown ${accessUser} ${containerPath}"
          else
            echo "Changing user of container path: ${containerPath} to: ${accessUser} recursively"
            containerCommand "${containerName}" "chown -R ${accessUser} ${containerPath}"
          fi
          containerUserName=$(containerCommandQuiet "${containerName}" "stat -L -c \"%U\" ${containerPath}")
          if [[ "${containerUserName}" == "${accessUser}" ]]; then
            echo "Successfully changed owner of container path: ${containerPath} to: ${accessUser}" | sed $'s,.*,\e[1;36m&\e[m,'
          else
            >&2 echo "Could not change owner of container path: ${containerPath} to: ${accessUser}"
            exit 1
          fi
        elif [[ -n "${mode}" ]] && [[ "${mode}" != "-" ]]; then
          >&2 echo "Unknown container path mode: ${mode} to container path: ${containerPath}"
          exit 1
        fi
      else
        if [[ "${missingMode}" == "i" ]]; then
          echo "Container path: ${containerPath} does not exist" | sed $'s,.*,\e[1;33m&\e[m,'
        else
          >&2 echo "Container path: ${containerPath} does not exist"
          exit 1
        fi
      fi
    else
      >&2 echo "No container path to prepare"
      exit 1
    fi
  else
    >&2 echo "Not possible to prepare path of container: ${containerName}"
    exit 1
  fi
}

# shellcheck disable=SC2034
typeset -fx containerPath

containerPathGroup()
{
  local containerName="${1}"
  local containerPath="${2}"
  local containerGroupId
  local containerGroupName

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ -n "${containerPath}" ]]; then
      if [[ $(containerCommandQuiet "${containerName}" "[[ -e ${containerPath} ]] && echo \"true\" || echo \"false\"") == "true" ]]; then
        containerGroupId=$(containerCommandQuiet "${containerName}" "stat -c \"%g\" ${containerPath}")
        containerGroupName=$(containerCommandQuiet "${containerName}" "getent group ${containerGroupId} | tr ':' ' ' | awk '{print \$1}'")
        containerGroupName=$(prepareValue "${containerGroupName}")

        if [[ -z "${containerGroupName}" ]]; then
          containerGroupName="docker_volume_${containerGroupId}"
          echo "Creating new group: ${containerGroupName}"
          containerCommand "${containerName}" "groupadd -g ${containerGroupId} ${containerGroupName}"
        else
          echo "No need to create group: ${containerGroupName}"
        fi
      fi
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerPathGroup

containerPathUser()
{
  local containerName="${1}"
  local containerPath="${2}"
  local containerUserId
  local containerUserName
  local containerGroupId

  if [[ $(containerExists "${containerName}") == 1 ]]; then
    if [[ -n "${containerPath}" ]]; then
      if [[ $(containerCommandQuiet "${containerName}" "[[ -e ${containerPath} ]] && echo \"true\" || echo \"false\"") == "true" ]]; then
        containerUserId=$(containerCommandQuiet "${containerName}" "stat -L -c \"%u\" ${containerPath}")
        containerUserName=$(containerCommandQuiet "${containerName}" "getent passwd ${containerUserId} | cat" | tr ':' ' ' | awk '{print $1}')
        containerUserName=$(prepareValue "${containerUserName}")

        if [[ -z "${containerUserName}" ]]; then
          containerGroupId=$(containerCommandQuiet "${containerName}" "stat -c \"%g\" ${containerPath}")

          containerUserName="docker_volume_${containerUserId}"
          echo "Creating new user: ${containerUserName}"
          containerCommand "${containerName}" "useradd -m -u ${containerUserId} -g ${containerGroupId} ${containerUserName}"
        else
          echo "No need to create user: ${containerUserName}"
        fi
      fi
    fi
  fi
}

# shellcheck disable=SC2034
typeset -fx containerPathUser

containerPathUserGroup()
{
  local containerName="${1}"
  local containerPath="${2}"
  local accessUser="${3}"
  local containerGroupId
  local containerGroupName
  local userId
  local result

  containerGroupId=$(containerCommandQuiet "${containerName}" "stat -c \"%g\" ${containerPath}")
  containerGroupName=$(containerCommandQuiet "${containerName}" "getent group ${containerGroupId} | tr ':' ' ' | awk '{print \$1}'")
  containerGroupName=$(prepareValue "${containerGroupName}")

  containerUserGroup "${containerName}" "${accessUser}" "${containerGroupName}"
}

# shellcheck disable=SC2034
typeset -fx containerPathUserGroup

containerUserGroup()
{
  local containerName="${1}"
  local accessUser="${2}"
  local containerGroupName="${3}"
  local userId
  local result

  if [[ "${accessUser}" == "local" ]] || [[ "${accessUser}" == "me" ]]; then
    userId="${UID}"
    accessUser=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | tr ':' ' ' | awk '{print \$1}'")
    accessUser=$(prepareValue "${accessUser}")
  fi

  result=$(containerCommandQuiet "${containerName}" "id -nG ${accessUser} | grep -w ${containerGroupName} | wc -l")
  result=$(prepareValue "${result}")

  if [[ "${result}" == 0 ]]; then
    echo "Adding user: ${accessUser} to group: ${containerGroupName}"
    containerCommand "${containerName}" "usermod -a -G ${containerGroupName} ${accessUser}"
  else
    echo "No need to add user: ${accessUser} to group: ${containerGroupName}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerUserGroup

containerPathLocalUser()
{
  local containerName="${1}"
  local containerPath="${2}"
  local userId
  local accessUser
  local containerGroupId

  userId="${UID}"
  accessUser=$(containerCommandQuiet "${containerName}" "getent passwd ${userId} | tr ':' ' ' | awk '{print \$1}'")
  accessUser=$(prepareValue "${accessUser}")

  if [[ -z "${accessUser}" ]]; then
    accessUser="docker_volume_${userId}"
    containerGroupId=$(containerCommandQuiet "${containerName}" "stat -c \"%g\" ${containerPath}")
    echo "Creating new user: ${accessUser} with group id: ${containerGroupId}"
    containerCommand "${containerName}" "useradd -m -u ${userId} -g ${containerGroupId} ${accessUser}"
  else
    echo "No need to create user: ${accessUser}"
  fi
}

# shellcheck disable=SC2034
typeset -fx containerPathLocalUser
