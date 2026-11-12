#!/bin/bash
# shellcheck disable=SC2016

# Unit tests for code that does not need Docker: the parameter parsing of prepare-parameters.sh and the port registry.
# They run in a few seconds and use a temporary directory as user var path, so ~/.anodosys is not touched.

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} [--keep]

Runs the unit tests that do not need Docker.

OPTIONS:
  --keep  Do not remove the temporary directory at the end
EOF
}

keep=0

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    -h|--help|-\?) usage; exit 0;;
    --keep) keep=1;;
    *) >&2 echo "Unknown option: ${1}"; usage; exit 1;;
  esac
  shift
done

for requiredCommand in jq flock xargs; do
  if ! command -v "${requiredCommand}" >/dev/null 2>&1; then
    >&2 echo "Please install required command: ${requiredCommand}"
    exit 1
  fi
done

appPath=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
testPath=$(mktemp -d)

passed=0
failed=0
failedTests=()
currentTest=
currentTestFailed=0

cleanup()
{
  if [[ "${keep}" == 1 ]]; then
    echo "Kept test files in: ${testPath}"
  else
    rm -rf "${testPath}"
  fi
}

trap cleanup EXIT

startTest()
{
  currentTest="${1}"
  currentTestFailed=0
  echo ""
  echo "- ${currentTest} -" | sed $'s,.*,\e[1;37m&\e[m,'
}

pass()
{
  echo "  ok: ${1}" | sed $'s,.*,\e[0;32m&\e[m,'
}

fail()
{
  echo "  failed: ${1}" | sed $'s,.*,\e[1;31m&\e[m,'
  failedTests+=( "${currentTest}: ${1}" )
  currentTestFailed=1
}

finishTest()
{
  if [[ "${currentTestFailed}" == 1 ]]; then
    failed=$((failed+1))
  else
    passed=$((passed+1))
  fi
}

assertEquals()
{
  local description="${1}"
  local expected="${2}"
  local actual="${3}"

  if [[ "${actual}" == "${expected}" ]]; then
    pass "${description}"
  else
    fail "${description}: got '${actual}', expected '${expected}'"
  fi
}

# --- prepare-parameters.sh ---

# sources prepare-parameters.sh in a new shell with the given arguments (like anodosys.sh does with its own) and prints
# the result of the expression evaluated afterwards: parseParameters <expression> <arguments...>
parseParameters()
{
  local expression="${1}"
  shift

  env -i PATH="${PATH}" preparePath="${appPath}/app/prepare-parameters.sh" expression="${expression}" \
    bash -c 'source "${preparePath}"; eval "${expression}"' parse "$@" 2>&1
}

startTest "parameters: key and value"
assertEquals "--server web" "web" "$(parseParameters 'echo "${server}"' --server web)"
assertEquals "single dash with value" "web" "$(parseParameters 'echo "${s}"' -s web)"
assertEquals "value with spaces" "a b" "$(parseParameters 'echo "${name}"' --name "a b")"
assertEquals "negative number as value" "-1" "$(parseParameters 'echo "${offset}"' --offset -1)"
assertEquals "later value wins" "b" "$(parseParameters 'echo "${server}"' --server a --server b)"
finishTest

startTest "parameters: flags"
assertEquals "flag at the end" "1" "$(parseParameters 'echo "${force}"' --force)"
assertEquals "flag before key" "1 web" "$(parseParameters 'echo "${force} ${server}"' --force --server web)"
assertEquals "flag after key" "web 1" "$(parseParameters 'echo "${server} ${force}"' --server web --force)"
assertEquals "single dash flag at the end is skipped" "unset" "$(parseParameters 'echo "${s-unset}"' -s)"
assertEquals "single dash flag before key is skipped" "unset web" \
  "$(parseParameters 'echo "${s-unset} ${server}"' -s --server web)"
finishTest

# hook parameters in the configuration are single strings like "--version 8.2" or "-port 9000"
startTest "parameters: key and value in one argument"
assertEquals "--version 8.2" "8.2" "$(parseParameters 'echo "${version}"' "--version 8.2")"
assertEquals "-port 9000" "9000" "$(parseParameters 'echo "${port}"' "-port 9000")"
assertEquals "value with spaces" "a b|unset" "$(parseParameters 'echo "${name}|${namea-unset}"' "--name a b")"
assertEquals "value is trimmed" "a b" "$(parseParameters 'echo "${name}"' "--name   a b  ")"
assertEquals "mixed with separate arguments" "8.2 web" \
  "$(parseParameters 'echo "${version} ${server}"' "--version 8.2" --server web)"
finishTest

startTest "parameters: positional arguments"
assertEquals "positional arguments stay in order" "rise|extra" \
  "$(parseParameters 'IFS="|"; echo "$*"' rise --server web extra)"
assertEquals "no positional arguments" "0" "$(parseParameters 'echo "$#"' --server web --force)"
assertEquals "argument with spaces stays one" "2" "$(parseParameters 'echo "$#"' "a b" c)"
finishTest

startTest "parameters: lists"
assertEquals "prepareParametersList" "--server web|--force" \
  "$(parseParameters 'IFS="|"; echo "${prepareParametersList[*]}"' --server web --force)"
assertEquals "prepareParametersListParts" "--server|web|--force|1" \
  "$(parseParameters 'IFS="|"; echo "${prepareParametersListParts[*]}"' --server web --force)"
assertEquals "prepareParameters" "web" \
  "$(parseParameters 'echo "${prepareParameters[server]}"' --server web)"
finishTest

startTest "parameters: help"
assertEquals "no help" "0" "$(parseParameters 'echo "${helpRequested}"' --server web)"
assertEquals "--help with an action" "1" "$(parseParameters 'echo "${helpRequested}"' rise --help)"
assertEquals "-? with an action" "1" "$(parseParameters 'echo "${helpRequested}"' rise -?)"
assertEquals "--help without action calls usage and exits" "usage" \
  "$(env -i PATH="${PATH}" preparePath="${appPath}/app/prepare-parameters.sh" \
    bash -c 'usage() { echo usage; }; source "${preparePath}"; echo continued' parse --help)"
finishTest

# --- port registry ---

anodosysUserVarPath="${testPath}/var"
mkdir -p "${anodosysUserVarPath}"
# shellcheck disable=SC1091
source "${appPath}/lib/port/registry.sh"

# ports of containers of other systems, without asking Docker
foreignPorts=()
portRegistryForeignPorts()
{
  if [[ "${#foreignPorts[@]}" -gt 0 ]]; then
    printf '%s\n' "${foreignPorts[@]}"
  fi
}

registryValue()
{
  jq -r --arg key "${1}" '.[$key] // "none"' "${anodosysUserVarPath}/ports.json"
}

startTest "port registry: specifications"
assertEquals "host and container port" "8080:80" "$(portRegistryResolve sys web 8080:80 2>/dev/null)"
assertEquals "stored in registry" "8080" "$(registryValue sys/web/80)"
assertEquals "only container port" "80" "$(portRegistryResolve sys web 80 2>/dev/null)"
assertEquals "ip and protocol are kept" "127.0.0.1:9000:90/udp" \
  "$(portRegistryResolve sys web 127.0.0.1:9000:90/udp 2>/dev/null)"
assertEquals "protocol is part of the key" "9000" "$(registryValue sys/web/90/udp)"
assertEquals "host port that is no number is passed on" "\${PORT}:81" \
  "$(portRegistryResolve sys web "\${PORT}:81" 2>/dev/null)"
assertEquals "nothing stored for it" "none" "$(registryValue sys/web/81)"
finishTest

startTest "port registry: assignment"
assertEquals "same request keeps its port" "8080:80" "$(portRegistryResolve sys web 8080:80 2>/dev/null)"
assertEquals "taken port gets the next free one" "8081:80" "$(portRegistryResolve sys api 8080:80 2>/dev/null)"
assertEquals "message about the other port" \
  "Host port: 8080 is used by another system, assigned host port: 8082 to: other/web/80" \
  "$(portRegistryResolve other web 8080:80 2>&1 >/dev/null)"
assertEquals "assigned port is kept for a new request" "8082:80" \
  "$(portRegistryResolve other web 8085:80 2>/dev/null)"
assertEquals "lookup" "8081" "$(portRegistryLookup sys api 80)"
assertEquals "lookup without assignment" "" "$(portRegistryLookup sys none 80)"
finishTest

startTest "port registry: ports of other systems"
foreignPorts=( 7000 7001 )
assertEquals "ports of other containers are skipped" "7002:80" "$(portRegistryResolve foreign web 7000:80 2>/dev/null)"
foreignPorts=()
finishTest

startTest "port registry: parallel assignment"
for index in 1 2 3 4 5 6; do
  portRegistryResolve parallel "server${index}" 6000:80 > "${testPath}/parallel${index}" 2>/dev/null &
done
wait
assignedPorts=$(cat "${testPath}"/parallel* | sort | tr '\n' ' ')
assertEquals "every server gets its own port" "6000:80 6001:80 6002:80 6003:80 6004:80 6005:80 " "${assignedPorts}"
if jq empty "${anodosysUserVarPath}/ports.json" 2>/dev/null; then
  pass "registry is valid JSON"
else
  fail "registry is no valid JSON"
fi
finishTest

echo ""
if [[ "${failed}" == 0 ]]; then
  echo "All ${passed} unit tests passed" | sed $'s,.*,\e[0;32m&\e[m,'
  exit 0
fi

echo "${failed} of $((passed+failed)) unit tests failed:" | sed $'s,.*,\e[1;31m&\e[m,'
for failedTest in "${failedTests[@]}"; do
  echo "  ${failedTest}"
done
exit 1
