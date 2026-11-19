#!/bin/bash
# shellcheck disable=SC2016

# Unit tests for code that does not need Docker: the parameter parsing of prepare-parameters.sh, the port registry and the systems file.
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

# --- systems file ---

anodosysUserPath="${testPath}/user"
mkdir -p "${anodosysUserPath}"
# shellcheck disable=SC1091
source "${appPath}/lib/system/add.sh"
# shellcheck disable=SC1091
source "${appPath}/lib/system/remove.sh"

systemsKeys()
{
  jq -r 'keys | join(" ")' "${anodosysUserPath}/systems.json"
}

startTest "systems file: add and remove"
systemAdd one /path/one/ads.json > /dev/null
systemAdd two /path/two/ads.json > /dev/null
assertEquals "added" "one two" "$(systemsKeys)"
assertEquals "configuration file" "/path/one/ads.json" "$(jq -r '.one' "${anodosysUserPath}/systems.json")"
assertEquals "existing system is not added again" "No need to add system with name: one" \
  "$(systemAdd one /path/other/ads.json)"
systemRemove one > /dev/null
assertEquals "removed" "two" "$(systemsKeys)"
: > "${anodosysUserPath}/systems.json"
systemAdd three /path/three/ads.json > /dev/null
assertEquals "empty file is started again" "three" "$(systemsKeys)"
finishTest

startTest "systems file: parallel changes"
for index in 1 2 3 4 5 6 7 8; do
  systemAdd "keep${index}" "/path/keep${index}/ads.json" > /dev/null &
  systemRemove three > /dev/null &
done
wait
assertEquals "every added system is kept" "keep1 keep2 keep3 keep4 keep5 keep6 keep7 keep8" "$(systemsKeys)"
finishTest

# --- volume metadata ---

anodosysUserVarVolumePath="${testPath}/volume"
mkdir -p "${anodosysUserVarVolumePath}"
# shellcheck disable=SC1091
source "${appPath}/lib/volume/meta.sh"

startTest "volume metadata: parallel creation of the same container"
metadataFile=$(volumeMetadataFilePath unit_status /run/docker.sock no)
volumeMetadataCreate unit_status /run/docker.sock /var/run/docker.sock www-data r 0 root 988 docker 660 false > /dev/null
invalidReads=0
for index in 1 2 3 4 5 6 7 8 9 10 11 12; do
  volumeMetadataCreate unit_status /run/docker.sock /var/run/docker.sock www-data r 0 root 988 docker 660 false > /dev/null &
done
for index in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if ! jq -e . "${metadataFile}" > /dev/null 2>&1; then
    invalidReads=$((invalidReads+1))
  fi
done
wait
assertEquals "every read finds valid JSON" "0" "${invalidReads}"
assertEquals "file is valid JSON" "www-data r docker 660" \
  "$(jq -r '[.targetUser, .mode, .group, .rights] | join(" ")' "${metadataFile}")"
assertEquals "value is read" "/var/run/docker.sock" "$(volumeMetadataGet unit_status /run/docker.sock targetPath)"
assertEquals "no temporary file is left" "1" "$(find "${anodosysUserVarVolumePath}" -type f | wc -l)"
finishTest

# --- extension versions ---

# shellcheck disable=SC1091
source "${appPath}/lib/extension/version.sh"

satisfies()
{
  versionSatisfies "${1}" "${2}" 2>/dev/null
}

startTest "extension versions: comparison"
assertEquals "lower" "-1" "$(versionCompare 1.2.3 1.10.0)"
assertEquals "equal with missing parts" "0" "$(versionCompare 1.2 1.2.0)"
assertEquals "higher" "1" "$(versionCompare 2.0.0 1.99.99)"
assertEquals "leading v" "0" "$(versionCompare v1.0.0 1.0.0)"
finishTest

startTest "extension versions: constraints"
assertEquals "any" "1" "$(satisfies 3.4.5 "*")"
assertEquals "exact" "1" "$(satisfies 1.2.3 1.2.3)"
assertEquals "exact other" "0" "$(satisfies 1.2.4 1.2.3)"
assertEquals "caret same major" "1" "$(satisfies 1.9.0 ^1.2)"
assertEquals "caret lower" "0" "$(satisfies 1.1.9 ^1.2)"
assertEquals "caret next major" "0" "$(satisfies 2.0.0 ^1.2)"
assertEquals "caret zero major" "0" "$(satisfies 0.3.0 ^0.2.1)"
assertEquals "caret zero major same minor" "1" "$(satisfies 0.2.5 ^0.2.1)"
assertEquals "caret zero minor" "0" "$(satisfies 0.0.4 ^0.0.3)"
assertEquals "tilde minor" "1" "$(satisfies 1.2.9 ~1.2)"
assertEquals "tilde next minor" "0" "$(satisfies 1.3.0 ~1.2)"
assertEquals "tilde major only" "1" "$(satisfies 1.9.0 ~1)"
assertEquals "wildcard" "1" "$(satisfies 1.2.7 1.2.*)"
assertEquals "wildcard other minor" "0" "$(satisfies 1.3.0 1.2.*)"
assertEquals "x wildcard" "1" "$(satisfies 1.9.0 1.x)"
assertEquals "range" "1" "$(satisfies 1.5.0 ">=1.2 <2")"
assertEquals "range with comma" "0" "$(satisfies 2.0.0 ">=1.2, <2")"
assertEquals "operator with space" "1" "$(satisfies 1.5.0 ">= 1.2")"
assertEquals "alternatives" "1" "$(satisfies 3.1.0 "^1 || ^3")"
assertEquals "alternatives none" "0" "$(satisfies 2.1.0 "^1 || ^3")"
assertEquals "dev matches dev" "1" "$(satisfies dev dev)"
assertEquals "dev does not match a version" "0" "$(satisfies dev ^1)"
assertEquals "invalid constraint" "0" "$(satisfies 1.0.0 "^foo")"
assertEquals "highest matching" "1.4.0" "$(versionHighest $'^1\n<1.5' 1.0.0 2.0.0 1.4.0 1.10.0)"
assertEquals "highest of all" "1.10.0" "$(versionHighest "*" 1.0.0 1.4.0 1.10.0)"
assertEquals "highest of none" "" "$(versionHighest "^3" 1.0.0 2.0.0)"
finishTest

# --- extension manager ---

if [[ $(id -u) == 0 ]]; then
  echo ""
  echo "Skipping the extension manager tests as root, they would install into the checkout"
else
  repositoryPath="${testPath}/repositories"
  extensionUserPath="${testPath}/extension-user"
  mkdir -p "${repositoryPath}" "${extensionUserPath}" "${testPath}/registry"

  # adds a version (tag) with the given extension.json to a repository: addVersion <repository> <version> <manifest>
  addVersion()
  {
    local repository="${repositoryPath}/${1}"

    if [[ ! -d "${repository}/.git" ]]; then
      git init --quiet "${repository}"
    fi
    echo "${3}" > "${repository}/extension.json"
    echo "${2}" > "${repository}/VERSION"
    git -C "${repository}" add -A
    git -C "${repository}" -c user.name=test -c user.email=test@example.com commit --quiet -m "${2}"
    if [[ "${2}" != "dev" ]]; then
      git -C "${repository}" tag "${2}"
    fi
  }

  addVersion cosyses 1.0.0 '{"name": "cosyses"}'
  addVersion cosyses 1.1.0 '{"name": "cosyses"}'
  addVersion cosyses 2.0.0 '{"name": "cosyses"}'
  addVersion fewedev 1.0.0 '{"name": "fewedev", "requires": {"cosyses": "^1"}}'
  addVersion fewedev 1.1.0 '{"name": "fewedev", "requires": {"cosyses": "^1.1"}}'
  addVersion fewedev 2.0.0 '{"name": "fewedev", "requires": {"cosyses": "^2"}}'
  # magento is in no registry, its dependency fewedev is found through the registry
  addVersion magento 1.0.0 '{"name": "magento", "requires": {"fewedev": "^1"}}'
  # infrangible names where magento is, like a private extension that requires another private one
  addVersion infrangible 1.0.0 "{\"name\": \"infrangible\", \"requires\": {\"magento\": \"^1\"}, \"sources\": {\"magento\": \"${repositoryPath}/magento\"}}"
  addVersion notags dev '{"name": "notags"}'
  addVersion future 1.0.0 '{"name": "future", "anodosys": ">=999"}'
  mkdir -p "${testPath}/checkout"
  echo '{"name": "checkout", "requires": {"cosyses": "^1"}}' > "${testPath}/checkout/extension.json"

  cat > "${testPath}/registry/registry.json" << EOF
{
  "extensions": {
    "cosyses": {"url": "${repositoryPath}/cosyses", "description": "Cosyses images"},
    "fewedev": "${repositoryPath}/fewedev",
    "future": "${repositoryPath}/future"
  }
}
EOF

  # runs ads extension in a clean environment against the test registry
  extension()
  {
    env -i PATH="${PATH}" HOME="${testPath}" ANODOSYS_USER_PATH="${extensionUserPath}" ANODOSYS_REGISTRY="${testPath}/registry" \
      bash "${appPath}/extension.sh" "$@" 2>&1
  }

  installed()
  {
    local name

    for name in $(jq -r 'keys[]' "${extensionUserPath}/extensions.json"); do
      echo -n "${name}=$(jq -r --arg name "${name}" '.[$name].version' "${extensionUserPath}/extensions.json") "
    done
  }

  startTest "extension manager: install with dependencies"
  output=$(extension install "${repositoryPath}/magento")
  assertEquals "installed with the highest matching versions" "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  assertEquals "requested" "true" "$(jq -r '.magento.explicit' "${extensionUserPath}/extensions.json")"
  assertEquals "dependency" "false" "$(jq -r '.fewedev.explicit' "${extensionUserPath}/extensions.json")"
  assertEquals "linked into the extension directory" "1.1.0" "$(cat "${extensionUserPath}/extension/fewedev/VERSION")"
  assertEquals "commit recorded" "40" "$(jq -r '.cosyses.commit | length' "${extensionUserPath}/extensions.json")"
  assertEquals "no git data" "no" "$([[ -d "${extensionUserPath}/extension/cosyses/.git" ]] && echo yes || echo no)"
  assertEquals "check" "0" "$(extension check > /dev/null; echo $?)"
  finishTest

  startTest "extension manager: conflicts"
  output=$(extension install fewedev@^2; echo "exit:$?")
  assertEquals "conflicting constraint fails" "exit:1" "${output##*$'\n'}"
  if [[ "${output}" == *"^2 (requested)"* ]] && [[ "${output}" == *"^1 (magento 1.0.0)"* ]]; then
    pass "conflict names the constraints"
  else
    fail "conflict does not name the constraints: ${output}"
  fi
  assertEquals "nothing changed" "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  output=$(extension remove fewedev; echo "exit:$?")
  assertEquals "required extension is not removed" "exit:1" "${output##*$'\n'}"
  assertEquals "still installed" "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  output=$(extension install future; echo "exit:$?")
  assertEquals "too new for this Anodosys" "exit:1" "${output##*$'\n'}"
  finishTest

  startTest "extension manager: update"
  addVersion cosyses 1.2.0 '{"name": "cosyses"}'
  extension install cosyses@1.1.0 > /dev/null
  extension update > /dev/null
  assertEquals "pinned version stays" "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  extension install cosyses@^1 > /dev/null
  extension update cosyses > /dev/null
  assertEquals "highest matching, not 2.0.0" "cosyses=1.2.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  assertEquals "older version removed from the store" "1.2.0" \
    "$(find "${extensionUserPath}/var/extension/cosyses" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')"
  finishTest

  startTest "extension manager: remove with dependencies"
  extension remove magento > /dev/null
  assertEquals "dependencies go, requested cosyses stays" "cosyses=1.2.0 " "$(installed)"
  assertEquals "link removed" "no" "$([[ -e "${extensionUserPath}/extension/fewedev" ]] && echo yes || echo no)"
  finishTest

  startTest "extension manager: sources of requiring extensions"
  extension install "${repositoryPath}/infrangible" > /dev/null
  assertEquals "magento found through the sources of infrangible" \
    "cosyses=1.2.0 fewedev=1.1.0 infrangible=1.0.0 magento=1.0.0 " "$(installed)"
  extension remove infrangible > /dev/null
  finishTest

  startTest "extension manager: default branch"
  output=$(extension install "${repositoryPath}/notags")
  assertEquals "installed as dev" "dev" "$(jq -r '.notags.version' "${extensionUserPath}/extensions.json")"
  addVersion notags dev '{"name": "notags", "changed": true}'
  extension update notags > /dev/null
  assertEquals "update fetches the branch again" "true" "$(jq -r '.changed' "${extensionUserPath}/extension/notags/extension.json")"
  extension remove notags > /dev/null
  finishTest

  startTest "extension manager: linked checkout"
  output=$(extension link "${testPath}/checkout")
  assertEquals "linked" "${testPath}/checkout" "$(readlink -f "${extensionUserPath}/extension/checkout")"
  assertEquals "requirement installed" "cosyses=1.2.0 " "$(installed)"
  output=$(extension remove cosyses; echo "exit:$?")
  assertEquals "required by the checkout" "exit:1" "${output##*$'\n'}"
  if [[ "$(extension list)" == *"checkout"*"linked"*"${testPath}/checkout"* ]]; then
    pass "listed as linked"
  else
    fail "not listed as linked: $(extension list)"
  fi
  output=$(extension install checkout; echo "exit:$?")
  assertEquals "linked extension is not replaced without --force" "exit:1" "${output##*$'\n'}"
  extension unlink checkout > /dev/null
  assertEquals "unlinked" "no" "$([[ -e "${extensionUserPath}/extension/checkout" ]] && echo yes || echo no)"
  assertEquals "requested cosyses stays" "cosyses=1.2.0 " "$(installed)"
  finishTest

  startTest "extension manager: registries"
  mkdir -p "${testPath}/private"
  echo "{\"extensions\": {\"magento\": \"${repositoryPath}/magento\", \"cosyses\": \"${repositoryPath}/fewedev\"}}" > "${testPath}/private/registry.json"
  extension registry add "${testPath}/private" > /dev/null
  assertEquals "listed before the public one" "${testPath}/private|${testPath}/registry" "$(extension registry list | tr '\n' '|' | sed 's/|$//')"
  extension install magento > /dev/null
  assertEquals "installed by name from the private registry" \
    "cosyses=1.2.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  if [[ "$(extension search)" == *"Extension: cosyses of registry: ${testPath}/registry is replaced"* ]]; then
    pass "replaced extension is reported"
  else
    fail "replaced extension is not reported: $(extension search)"
  fi
  assertEquals "installed url is kept" "${repositoryPath}/cosyses" "$(jq -r '.cosyses.url' "${extensionUserPath}/extensions.json")"
  extension registry remove "${testPath}/private" > /dev/null
  assertEquals "removed" "${testPath}/registry" "$(extension registry list)"
  finishTest

  startTest "extension manager: older installations"
  extension remove magento cosyses > /dev/null
  mkdir -p "${extensionUserPath}/extension/cosyses"
  if [[ "$(extension list)" == *"cosyses"*"local"* ]]; then
    pass "plain directory is listed as local"
  else
    fail "plain directory is not listed as local: $(extension list)"
  fi
  output=$(extension install cosyses; echo "exit:$?")
  assertEquals "not replaced without --force" "exit:1" "${output##*$'\n'}"
  extension install cosyses --force > /dev/null
  assertEquals "replaced with --force" "cosyses=2.0.0 " "$(installed)"
  finishTest

  startTest "extension manager: problems of installed extensions"
  mkdir -p "${extensionUserPath}/extension/manual"
  echo '{"name": "manual", "requires": {"cosyses": "^1", "missing": "^1"}}' > "${extensionUserPath}/extension/manual/extension.json"
  output=$(extension check; echo "exit:$?")
  assertEquals "check fails" "exit:1" "${output##*$'\n'}"
  if [[ "${output}" == *"requires extension: missing ^1, which is not installed, run: ads extension install missing"* ]]; then
    pass "missing extension reported"
  else
    fail "missing extension not reported: ${output}"
  fi
  if [[ "${output}" == *"requires extension: cosyses ^1, installed is: 2.0.0, run: ads extension update cosyses"* ]]; then
    pass "unsuitable version reported"
  else
    fail "unsuitable version not reported: ${output}"
  fi
  finishTest

  # systems that require extensions, with a new user path
  extensionUserPath="${testPath}/extension-systems"
  mkdir -p "${extensionUserPath}" "${testPath}/shop/ads" "${testPath}/blog"
  cat > "${testPath}/shop/ads/ads.json" << EOF
{
  "extensions": {
    "magento": {"version": "^1.0", "source": "${repositoryPath}/magento"},
    "cosyses": "~1.1"
  },
  "global": {"systemName": "shop"}
}
EOF
  echo '{"extensions": {"cosyses": "^1"}, "global": {"systemName": "blog"}}' > "${testPath}/blog/ads.json"
  echo "{\"blog\": \"${testPath}/blog/ads.json\"}" > "${extensionUserPath}/systems.json"

  startTest "extension manager: extensions of systems"
  output=$(cd "${testPath}/shop" && extension install)
  assertEquals "installed what the system requires, in its constraints" \
    "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  assertEquals "requested by the system" "true" "$(jq -r '.cosyses.explicit' "${extensionUserPath}/extensions.json")"
  assertEquals "system constraint is not stored as own constraint" "null" "$(jq -r '.cosyses.constraint' "${extensionUserPath}/extensions.json")"
  output=$(extension install cosyses@^2; echo "exit:$?")
  assertEquals "registered system keeps its constraint" "exit:1" "${output##*$'\n'}"
  if [[ "${output}" == *"^1 (system blog)"* ]]; then
    pass "conflict names the system"
  else
    fail "conflict does not name the system: ${output}"
  fi
  extension update > /dev/null
  assertEquals "update stays in the constraints of the registered system" \
    "cosyses=1.2.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  (cd "${testPath}/shop" && extension update > /dev/null)
  assertEquals "update in the system directory goes back into its constraint" \
    "cosyses=1.1.0 fewedev=1.1.0 magento=1.0.0 " "$(installed)"
  finishTest

  startTest "extension manager: check of systems"
  output=$(extension check; echo "exit:$?")
  assertEquals "registered system is fine" "exit:0" "${output##*$'\n'}"
  echo '{"extensions": {"cosyses": "~1.2"}, "global": {"systemName": "newer"}}' > "${testPath}/blog/newer.json"
  output=$(extension check --file "${testPath}/blog/newer.json"; echo "exit:$?")
  assertEquals "given system does not match" "exit:1" "${output##*$'\n'}"
  if [[ "${output}" == *"System: newer requires extension: cosyses ~1.2, installed is: 1.1.0, run: ads extension update cosyses"* ]]; then
    pass "unsuitable version reported"
  else
    fail "unsuitable version not reported: ${output}"
  fi
  # shellcheck disable=SC1091
  source "${appPath}/lib/extension/check.sh"
  echo '{"extensions": {"wordpress": "^1"}}' > "${testPath}/blog/missing.json"
  assertEquals "missing extension" \
    "System: blog requires extension: wordpress ^1, which is not installed, run: ads extension install (in: ${testPath}/blog)" \
    "$(extensionProjectProblems "${testPath}/blog/missing.json" blog "${extensionUserPath}")"
  assertEquals "no extensions" "" "$(extensionProjectProblems "${testPath}/shop/ads/missing.json" shop "${extensionUserPath}")"
  finishTest
fi

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
