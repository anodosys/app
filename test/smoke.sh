#!/bin/bash

# Smoke tests for the main actions. They build a small system with two Ubuntu containers (db and app, where app depends
# on db), run it through its lifecycle with the anodosys.sh of this checkout and remove everything afterwards.
#
# The tests use their own user path (ANODOSYS_USER_PATH) in a temporary directory, so ~/.anodosys with its extensions,
# systems.json and logs is not touched. They need Docker and create containers, a network and images named after a
# unique system name (adssmoke<pid>).

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} [--keep]

Runs the smoke tests for the main actions against Docker.

OPTIONS:
  --keep  Do not remove the temporary directory (configuration, logs and command output) at the end
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

for requiredCommand in docker jq jcp j2v ts setsid; do
  if ! command -v "${requiredCommand}" >/dev/null 2>&1; then
    >&2 echo "Please install required command: ${requiredCommand}"
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  >&2 echo "Docker is not available for the current user"
  exit 1
fi

appPath=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ads="${appPath}/anodosys.sh"

imageName="ubuntu"
imageTag="24.04"
system="adssmoke$$"
testPath=$(mktemp -d)
userPath="${testPath}/user"
projectPath="${testPath}/project"
constructPath="${testPath}/construct"
outputFile="${testPath}/output.txt"
mkdir -p "${projectPath}" "${constructPath}"

passed=0
failed=0
failedTests=()
currentTest=
lastExitCode=0

cleanup()
{
  local containerIds

  echo ""
  echo "Cleaning up system: ${system}" | sed $'s,.*,\e[1;37m&\e[m,'
  containerIds=$(docker ps -a -q --filter "label=com.docker.compose.project=${system}")
  if [[ -n "${containerIds}" ]]; then
    # shellcheck disable=SC2086
    docker rm -f ${containerIds} >/dev/null
  fi
  docker network rm "${system}" >/dev/null 2>&1
  docker rmi -f "${system}/db:smoke" "${system}/app:smoke" >/dev/null 2>&1
  if [[ "${keep}" == 1 ]]; then
    echo "Kept test files in: ${testPath}"
  else
    rm -rf "${testPath}"
  fi
}

trap cleanup EXIT

# runs anodosys.sh in the project directory with a clean environment and without terminal, so that all output ends up in
# the output file and no variable of the calling shell is turned into a parameter
runAds()
{
  local directory="${1}"
  shift

  (
    cd "${directory}" || exit 1
    env -i \
      HOME="${HOME}" \
      USER="${USER}" \
      PATH="${PATH}" \
      LANG="${LANG:-C.UTF-8}" \
      ANODOSYS_USER_PATH="${userPath}" \
      setsid -w timeout 600 "${ads}" "$@" </dev/null 2>&1 | sed $'s,\e\\[[0-9;]*m,,g' > "${outputFile}"
    exit "${PIPESTATUS[0]}"
  )
  lastExitCode=$?
}

startTest()
{
  currentTest="${1}"
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
  if [[ -f "${outputFile}" ]]; then
    tail -n 20 "${outputFile}" | sed 's,^,    | ,'
  fi
  failedTests+=( "${currentTest}: ${1}" )
}

finishTest()
{
  if [[ "${#failedTests[@]}" -gt 0 ]] && [[ "${failedTests[-1]%%:*}" == "${currentTest}" ]]; then
    failed=$((failed+1))
  else
    passed=$((passed+1))
  fi
}

assertExitCode()
{
  local expected="${1}"

  if [[ "${lastExitCode}" == "${expected}" ]]; then
    pass "exit code ${expected}"
  else
    fail "exit code ${lastExitCode}, expected ${expected}"
  fi
}

assertOutputContains()
{
  if grep -qF -- "${1}" "${outputFile}"; then
    pass "output contains: ${1}"
  else
    fail "output does not contain: ${1}"
  fi
}

assertContainerState()
{
  local server="${1}"
  local expected="${2}"
  local state

  state=$(docker inspect --format '{{.State.Status}}' "${system}_${server}" 2>/dev/null)
  if [[ "${state}" == "${expected}" ]]; then
    pass "container ${system}_${server} is ${expected}"
  else
    fail "container ${system}_${server} is ${state:-missing}, expected ${expected}"
  fi
}

assertContainerMissing()
{
  local server="${1}"

  if docker inspect "${system}_${server}" >/dev/null 2>&1; then
    fail "container ${system}_${server} still exists"
  else
    pass "container ${system}_${server} does not exist"
  fi
}

assertContainerImage()
{
  local server="${1}"
  local expected="${2}"
  local image

  image=$(docker inspect --format '{{.Config.Image}}' "${system}_${server}" 2>/dev/null)
  if [[ "${image}" == "${expected}" ]]; then
    pass "container ${system}_${server} uses image ${expected}"
  else
    fail "container ${system}_${server} uses image ${image:-none}, expected ${expected}"
  fi
}

assertImageExists()
{
  if docker image inspect "${1}" >/dev/null 2>&1; then
    pass "image ${1} exists"
  else
    fail "image ${1} does not exist"
  fi
}

assertImageMissing()
{
  if docker image inspect "${1}" >/dev/null 2>&1; then
    fail "image ${1} still exists"
  else
    pass "image ${1} does not exist"
  fi
}

assertNetwork()
{
  local expected="${1}"
  local exists=0

  if docker network inspect "${system}" >/dev/null 2>&1; then
    exists=1
  fi
  if [[ "${exists}" == "${expected}" ]]; then
    pass "network ${system} $([[ "${expected}" == 1 ]] && echo "exists" || echo "does not exist")"
  else
    fail "network ${system} $([[ "${exists}" == 1 ]] && echo "exists" || echo "does not exist")"
  fi
}

if ! docker image inspect "${imageName}:${imageTag}" >/dev/null 2>&1; then
  echo "Pulling image: ${imageName}:${imageTag}"
  docker pull -q "${imageName}:${imageTag}" >/dev/null
fi

# each container writes the time of its installation, so that the order of the dependency waves can be checked, and
# prints a progress line like Composer, which the log file has to reduce to its last state
cat > "${projectPath}/ads.json" << EOF
{
  "global": {
    "systemName": "${system}"
  },
  "system": {
    "serverNames": [
      "db",
      "app"
    ]
  },
  "any": {
    "imageName": "${imageName}",
    "imageTag": "${imageTag}",
    "buildImageTag": "smoke",
    "containerInstall": "date +%s%N > /tmp/installed; printf 'progress 1/2\\\\033[1G\\\\033[2Kprogress 2/2\\\\n'"
  },
  "db": {
    "buildImageName": "${system}/db"
  },
  "app": {
    "buildImageName": "${system}/app",
    "depends": [
      "db"
    ]
  }
}
EOF

echo "Running smoke tests with system: ${system} in: ${testPath}" | sed $'s,.*,\e[1;37m&\e[m,'

startTest "construct"
echo "{}" > "${constructPath}/ads.json"
runAds "${constructPath}" construct system --name constructed
assertExitCode 0
runAds "${constructPath}" construct property --serverName web --name imageTag --value "${imageTag}"
assertExitCode 0
if [[ $(jq -r '.global.systemName' "${constructPath}/ads.json") == "constructed" ]] && [[ $(jq -r '.web.imageTag' "${constructPath}/ads.json") == "${imageTag}" ]]; then
  pass "properties written to ads.json"
else
  fail "properties not written to ads.json: $(jq -c . "${constructPath}/ads.json")"
fi
finishTest

startTest "config"
runAds "${projectPath}" config
assertExitCode 0
assertOutputContains "\"systemName\": \"${system}\""
finishTest

startTest "names"
runAds "${projectPath}" names
assertExitCode 0
assertOutputContains "${system}_db"
assertOutputContains "${system}/app:smoke"
finishTest

startTest "step list"
runAds "${projectPath}" step
assertOutputContains "containerCreateSource"
finishTest

startTest "unknown action"
runAds "${projectPath}" nosuchaction
if [[ "${lastExitCode}" != 0 ]]; then
  pass "exit code ${lastExitCode}"
else
  fail "exit code 0 for an unknown action"
fi
finishTest

startTest "rise"
runAds "${projectPath}" rise
assertExitCode 0
assertContainerState db running
assertContainerState app running
assertContainerImage app "${imageName}:${imageTag}"
assertNetwork 1
dbInstalled=$(docker exec "${system}_db" cat /tmp/installed 2>/dev/null)
appInstalled=$(docker exec "${system}_app" cat /tmp/installed 2>/dev/null)
if [[ -n "${dbInstalled}" ]] && [[ -n "${appInstalled}" ]] && [[ "${dbInstalled}" -lt "${appInstalled}" ]]; then
  pass "db was installed before app, which depends on it"
else
  fail "install order wrong or missing, db: ${dbInstalled:-none}, app: ${appInstalled:-none}"
fi
if [[ $(jq -r --arg system "${system}" '.[$system] // empty' "${userPath}/systems.json" 2>/dev/null) == "${projectPath}/ads.json" ]]; then
  pass "system registered in systems.json"
else
  fail "system not registered in systems.json"
fi
finishTest

startTest "status"
runAds "${projectPath}" status
assertExitCode 0
assertOutputContains "${system}_db"
assertOutputContains "${system}_app"
finishTest

startTest "cmdq"
runAds "${projectPath}" cmdq app root "echo smoke-\$(hostname -s | wc -c)"
assertExitCode 0
assertOutputContains "smoke-"
finishTest

startTest "stop"
runAds "${projectPath}" stop
assertExitCode 0
assertContainerState db exited
assertContainerState app exited
finishTest

startTest "start"
runAds "${projectPath}" start
assertExitCode 0
assertContainerState db running
assertContainerState app running
finishTest

startTest "restart"
startedBefore=$(docker inspect --format '{{.State.StartedAt}}' "${system}_app" 2>/dev/null)
runAds "${projectPath}" restart
assertExitCode 0
assertContainerState app running
if [[ $(docker inspect --format '{{.State.StartedAt}}' "${system}_app" 2>/dev/null) != "${startedBefore}" ]]; then
  pass "container ${system}_app was started again"
else
  fail "container ${system}_app was not started again"
fi
finishTest

startTest "log"
runAds "${projectPath}" log --lines 1000
assertExitCode 0
logFilePath="${userPath}/var/log/${system}.log"
if [[ $(grep -c "^===== .* | anodosys.sh rise | ${projectPath} =====$" "${logFilePath}" 2>/dev/null) == 1 ]]; then
  pass "log file has a header for the rise run"
else
  fail "log file has no header for the rise run"
fi
if grep -q $'[\e\r]' "${logFilePath}" 2>/dev/null; then
  fail "log file contains control codes"
else
  pass "log file contains no control codes"
fi
if grep -q "\] progress 2/2$" "${logFilePath}" 2>/dev/null && ! grep -q "\] progress 1/2" "${logFilePath}" 2>/dev/null; then
  pass "progress output is reduced to its last state"
else
  fail "progress output is not reduced to its last state: $(grep "progress" "${logFilePath}" 2>/dev/null | head -n 2 | cat -v)"
fi
assertOutputContains "[${system}] [app]"
finishTest

startTest "list"
runAds "${projectPath}" list
assertExitCode 0
assertOutputContains "${system}"
finishTest

startTest "image"
runAds "${projectPath}" image
assertExitCode 0
assertImageExists "${system}/db:smoke"
assertImageExists "${system}/app:smoke"
assertContainerState app exited
finishTest

startTest "purge"
runAds "${projectPath}" purge
assertExitCode 0
assertContainerMissing db
assertContainerMissing app
assertNetwork 0
finishTest

startTest "purge without containers"
runAds "${projectPath}" purge
if [[ "${lastExitCode}" != 0 ]]; then
  pass "exit code ${lastExitCode}"
else
  fail "exit code 0 although no container exists"
fi
finishTest

startTest "run"
runAds "${projectPath}" run --local
assertExitCode 0
assertContainerState db running
assertContainerState app running
assertContainerImage app "${system}/app:smoke"
finishTest

startTest "erase"
runAds "${projectPath}" erase
assertExitCode 0
assertContainerMissing db
assertContainerMissing app
assertImageMissing "${system}/db:smoke"
assertImageMissing "${system}/app:smoke"
finishTest

echo ""
if [[ "${failed}" == 0 ]]; then
  echo "All ${passed} smoke tests passed" | sed $'s,.*,\e[0;32m&\e[m,'
  exit 0
fi

echo "${failed} of $((passed+failed)) smoke tests failed:" | sed $'s,.*,\e[1;31m&\e[m,'
for failedTest in "${failedTests[@]}"; do
  echo "  ${failedTest}"
done
exit 1
