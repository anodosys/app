#!/bin/bash -e

# Versions of extensions are bare semver tags (1.2.3, a leading v is accepted). Constraints follow Composer and npm:
# "*", "1.2.3", "=1.2.3", ">=1.2", ">1.2", "<=2", "<2", "^1.2", "~1.2", "1.2.*", "1.x", several of them separated by
# spaces or commas must all match, alternatives are separated by "||".

# prints the three numbers of a version separated by spaces, missing parts are 0, and returns 1 for no version
versionParts()
{
  local version="${1#v}"

  if [[ ! "${version}" =~ ^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?$ ]]; then
    return 1
  fi

  echo "$((10#${BASH_REMATCH[1]})) $((10#${BASH_REMATCH[3]:-0})) $((10#${BASH_REMATCH[5]:-0}))"
}

# shellcheck disable=SC2034
typeset -fx versionParts

# prints -1, 0 or 1 when the first version is lower, equal or higher than the second
versionCompare()
{
  local first
  local second
  local index

  read -r -a first <<< "$(versionParts "${1}")"
  read -r -a second <<< "$(versionParts "${2}")"

  for index in 0 1 2; do
    if [[ "${first[${index}]}" -lt "${second[${index}]}" ]]; then
      echo "-1"
      return 0
    fi
    if [[ "${first[${index}]}" -gt "${second[${index}]}" ]]; then
      echo "1"
      return 0
    fi
  done

  echo "0"
}

# shellcheck disable=SC2034
typeset -fx versionCompare

# prints 1 when the version matches one comparator (">=1.2", "^1", "1.2.*", ...), otherwise 0
versionMatchesComparator()
{
  local version="${1}"
  local comparator="${2}"
  local operator
  local value
  local parts
  local count
  local lower
  local upper

  if [[ -z "${comparator}" ]] || [[ "${comparator}" == "*" ]] || [[ "${comparator}" == "x" ]]; then
    echo "1"
    return 0
  fi

  if [[ ! "${comparator}" =~ ^(\^|~|>=|<=|>|<|=)?v?([0-9]+(\.([0-9]+|\*|x))?(\.([0-9]+|\*|x))?)$ ]]; then
    >&2 echo "Invalid version constraint: ${comparator}"
    echo "0"
    return 0
  fi

  operator="${BASH_REMATCH[1]}"
  value="${BASH_REMATCH[2]}"

  # wildcards: 1.2.* is >=1.2.0 <1.3.0, 1.* is >=1.0.0 <2.0.0
  if [[ "${value}" == *"*"* ]] || [[ "${value}" == *"x"* ]]; then
    if [[ -n "${operator}" ]] && [[ "${operator}" != "=" ]]; then
      >&2 echo "Invalid version constraint: ${comparator}"
      echo "0"
      return 0
    fi
    value="${value%%.[*x]*}"
    operator="~"
    if [[ "${value}" != *.* ]]; then
      operator="^"
      read -r -a parts <<< "$(versionParts "${value}")"
      lower="${parts[0]}.0.0"
      upper="$((parts[0]+1)).0.0"
      if [[ $(versionCompare "${version}" "${lower}") -ge 0 ]] && [[ $(versionCompare "${version}" "${upper}") -lt 0 ]]; then
        echo "1"
      else
        echo "0"
      fi
      return 0
    fi
  fi

  read -r -a parts <<< "$(versionParts "${value}")"
  count=$(($(tr -cd '.' <<< "${value}" | wc -c)+1))

  case "${operator}" in
    ""|"=")
      [[ $(versionCompare "${version}" "${value}") == 0 ]] && echo "1" || echo "0"
      return 0
      ;;
    ">=")
      [[ $(versionCompare "${version}" "${value}") -ge 0 ]] && echo "1" || echo "0"
      return 0
      ;;
    ">")
      [[ $(versionCompare "${version}" "${value}") -gt 0 ]] && echo "1" || echo "0"
      return 0
      ;;
    "<=")
      [[ $(versionCompare "${version}" "${value}") -le 0 ]] && echo "1" || echo "0"
      return 0
      ;;
    "<")
      [[ $(versionCompare "${version}" "${value}") -lt 0 ]] && echo "1" || echo "0"
      return 0
      ;;
    "^")
      # the first part that is not zero must stay the same
      if [[ "${parts[0]}" -gt 0 ]] || [[ "${count}" -eq 1 ]]; then
        upper="$((parts[0]+1)).0.0"
      elif [[ "${parts[1]}" -gt 0 ]] || [[ "${count}" -eq 2 ]]; then
        upper="0.$((parts[1]+1)).0"
      else
        upper="0.0.$((parts[2]+1))"
      fi
      ;;
    "~")
      # the last given part may increase, except for a single number
      if [[ "${count}" -eq 1 ]]; then
        upper="$((parts[0]+1)).0.0"
      else
        upper="${parts[0]}.$((parts[1]+1)).0"
      fi
      ;;
  esac

  if [[ $(versionCompare "${version}" "${value}") -ge 0 ]] && [[ $(versionCompare "${version}" "${upper}") -lt 0 ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# shellcheck disable=SC2034
typeset -fx versionMatchesComparator

# prints 1 when the version matches the constraint, otherwise 0; "dev" (the default branch) matches only "dev"
versionSatisfies()
{
  local version="${1}"
  local constraint="${2}"
  local alternatives
  local alternative
  local comparators
  local comparator
  local matches

  if [[ "${version}" == "dev" ]] || [[ "${constraint}" == "dev" ]]; then
    [[ "${version}" == "${constraint}" ]] && echo "1" || echo "0"
    return 0
  fi

  if ! versionParts "${version}" > /dev/null; then
    echo "0"
    return 0
  fi

  constraint="${constraint//||/|}"
  IFS='|' read -r -a alternatives <<< "${constraint}"
  if [[ "${#alternatives[@]}" -eq 0 ]]; then
    alternatives=( "*" )
  fi

  for alternative in "${alternatives[@]}"; do
    # ">= 1.2" is the same as ">=1.2"
    alternative=$(sed -E 's/(\^|~|>=|<=|>|<|=)[[:space:]]+/\1/g; s/,/ /g' <<< "${alternative}")
    read -r -a comparators <<< "${alternative}"
    matches=1
    for comparator in "${comparators[@]}"; do
      if [[ $(versionMatchesComparator "${version}" "${comparator}") != 1 ]]; then
        matches=0
        break
      fi
    done
    if [[ "${matches}" == 1 ]]; then
      echo "1"
      return 0
    fi
  done

  echo "0"
}

# shellcheck disable=SC2034
typeset -fx versionSatisfies

# prints the highest of the given versions that matches every constraint in the newline separated list, nothing if none
versionHighest()
{
  local constraints="${1}"
  shift
  local version
  local constraint
  local matches
  local highest=

  for version in "$@"; do
    matches=1
    while IFS= read -r constraint; do
      if [[ -n "${constraint}" ]] && [[ $(versionSatisfies "${version}" "${constraint}") != 1 ]]; then
        matches=0
        break
      fi
    done <<< "${constraints}"
    if [[ "${matches}" == 1 ]] && { [[ -z "${highest}" ]] || [[ $(versionCompare "${version}" "${highest}") -gt 0 ]]; }; then
      highest="${version}"
    fi
  done

  echo -n "${highest}"
}

# shellcheck disable=SC2034
typeset -fx versionHighest

# prints the version of the running Anodosys: the release directory of an installed release, the last tag of a checkout
anodosysCurrentVersion()
{
  local applicationPath="${1:-${anodosysPath}}"
  local version=

  if [[ -L "$(dirname "${applicationPath}")/current" ]]; then
    version=$(basename "${applicationPath}")
  elif [[ -d "${applicationPath}/.git" ]]; then
    version=$(git -C "${applicationPath}" describe --tags --abbrev=0 --match '[0-9]*' 2>/dev/null || true)
  fi

  if versionParts "${version}" > /dev/null 2>&1; then
    echo -n "${version}"
  fi
}

# shellcheck disable=SC2034
typeset -fx anodosysCurrentVersion
