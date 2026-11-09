#!/bin/bash

# Smoke tests for the main actions. They build a small system with two Ubuntu containers (db and app, where app depends
# on db), run it through its lifecycle with the anodosys.sh of this checkout and remove everything afterwards. A second
# system of plain Alpine images checks the bootstrap command and, when Docker can emulate arm64, the container platform.
#
# The tests use their own user path (ANODOSYS_USER_PATH) in a temporary directory, so ~/.anodosys with its extensions,
# systems.json and logs is not touched. They need Docker and create containers, a network and images named after a
# unique system name (adssmoke<pid>).

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} [--keep] [--cosyses <path>] [--proxy-only]

Runs the smoke tests for the main actions against Docker.

OPTIONS:
  --keep            Do not remove the temporary directory (configuration, logs and command output) at the end
  --cosyses <path>  Use this Cosyses checkout in the proxy container instead of the released Cosyses, to test with
                    routines that are not released yet (for example a new Traefik version)
  --proxy-only      Run only the tests of the proxy, the port registry and connect
EOF
}

keep=0
cosysesPath=
proxyOnly=0

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    -h|--help|-\?) usage; exit 0;;
    --keep) keep=1;;
    --cosyses) cosysesPath="${2}"; shift;;
    --proxy-only) proxyOnly=1;;
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
# db keeps /etc/skel (files from the image) in a data volume
dataVolume="${system}_db_data"

# a system of plain Alpine images (without bash), one of them for arm64 when Docker can emulate it
otherSystem="${system}x"
otherPath="${testPath}/other"
otherImageName="alpine"
otherImageTag="3.24"

# two more systems run at the same time behind an own proxy on free high ports, so that a running proxy on 80 and 443
# is not touched; both request the same host port to check the port registry
systemA="${system}a"
systemB="${system}b"
proxySystem="${system}proxy"
toolContainer="${system}tool"
proxyHttpPort=$((40000 + $$ % 10000))
proxyHttpsPort=$((50000 + $$ % 10000))
requestedPort=$((20000 + $$ % 10000))
proxyEnv=
proxyCosysesPath=
if [[ -n "${cosysesPath}" ]]; then
  # a copy, so that the volume handling cannot change the checkout
  mkdir -p "${testPath}/cosyses"
  tar -C "${cosysesPath}" --exclude=.git -cf - . | tar -C "${testPath}/cosyses" -xf -
  proxyEnv="NO_COSYSES_UPDATE=1"
  proxyCosysesPath="${testPath}/cosyses"
fi
mkdir -p "${projectPath}" "${constructPath}"

passed=0
failed=0
failedTests=()
currentTest=
currentTestFailed=0
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
  docker volume rm -f "${dataVolume}" >/dev/null 2>&1
  for project in "${systemA}" "${systemB}" "${system}l" "${otherSystem}" "${proxySystem}" "${toolContainer}"; do
    containerIds=$(docker ps -a -q --filter "label=com.docker.compose.project=${project}")
    if [[ -n "${containerIds}" ]]; then
      # shellcheck disable=SC2086
      docker rm -f ${containerIds} >/dev/null
    fi
    docker network rm "${project}" >/dev/null 2>&1
  done
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
      ANODOSYS_PROXY_SYSTEM="${proxySystem}" \
      ANODOSYS_PROXY_HTTP_PORT="${proxyHttpPort}" \
      ANODOSYS_PROXY_HTTPS_PORT="${proxyHttpsPort}" \
      ANODOSYS_PROXY_ENV="${proxyEnv}" \
      ANODOSYS_PROXY_COSYSES_PATH="${proxyCosysesPath}" \
      setsid -w timeout 900 "${ads}" "$@" </dev/null 2>&1 | sed $'s,\e\\[[0-9;]*m,,g' > "${outputFile}"
    exit "${PIPESTATUS[0]}"
  )
  lastExitCode=$?
}

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
  if [[ -f "${outputFile}" ]]; then
    tail -n 20 "${outputFile}" | sed 's,^,    | ,'
  fi
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

# the data volume of db outlives its container; the marker written into it after rise has to stay in it
assertDataVolume()
{
  local expectMarker="${1}"

  if [[ $(docker volume inspect --format '{{ index .Labels "anodosys.data" }}' "${dataVolume}" 2>/dev/null) == "true" ]]; then
    pass "data volume ${dataVolume} exists"
  else
    fail "data volume ${dataVolume} does not exist"
  fi
  if [[ "${expectMarker}" == 1 ]]; then
    if [[ $(docker run --rm -v "${dataVolume}:/data" "${imageName}:${imageTag}" cat /data/marker 2>/dev/null) == "kept" ]]; then
      pass "data volume ${dataVolume} kept its content"
    else
      fail "data volume ${dataVolume} lost its content"
    fi
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

# hook scripts of app: one on the host, two in the container (one as root, one as another user); each writes the
# parameters it received through prepare-parameters.sh
hookPath="${testPath}/hook"
mkdir -p "${hookPath}"
cat > "${hookPath}/host.sh" << EOF
#!/bin/bash -e
source "${appPath}/app/prepare-parameters.sh"
echo "\${containerName} \${marker}" > "${hookPath}/host.txt"
EOF
cat > "${hookPath}/before.sh" << 'EOF'
#!/bin/bash -e
source /prepare-parameters.sh
echo "${serverName} ${marker} ${mode} $(id -un)" > /tmp/hook-before
EOF
cat > "${hookPath}/after.sh" << 'EOF'
#!/bin/bash -e
source /prepare-parameters.sh
echo "${serverName} $(id -un)" > /tmp/hook-after
EOF
chmod +x "${hookPath}/host.sh" "${hookPath}/before.sh" "${hookPath}/after.sh"

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
    "buildImageName": "${system}/db",
    "containerDataVolumes": [
      "data:/etc/skel"
    ]
  },
  "app": {
    "buildImageName": "${system}/app",
    "depends": [
      "db"
    ],
    "beforeContainerInstallScript": "${hookPath}/host.sh",
    "beforeContainerInstallParameters": [
      "--marker host"
    ],
    "beforeContainerInstallDockerScript": "${hookPath}/before.sh",
    "beforeContainerInstallDockerParameters": [
      "--marker docker",
      "-mode single"
    ],
    "afterContainerInstallDockerScript": "${hookPath}/after.sh",
    "afterContainerInstallDockerUser": "nobody"
  }
}
EOF

echo "Running smoke tests with system: ${system} in: ${testPath}" | sed $'s,.*,\e[1;37m&\e[m,'

if [[ "${proxyOnly}" == 0 ]]; then

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
if docker exec "${system}_db" test -f /etc/skel/.bashrc 2>/dev/null; then
  pass "data volume was filled with the files of the image"
else
  fail "data volume was not filled with the files of the image"
fi
docker exec "${system}_db" sh -c 'echo kept > /etc/skel/marker'
assertDataVolume 1
finishTest

startTest "install hooks"
if [[ $(cat "${hookPath}/host.txt" 2>/dev/null) == "${system}_app host" ]]; then
  pass "host script got container name and parameters"
else
  fail "host script output: $(cat "${hookPath}/host.txt" 2>/dev/null || echo none)"
fi
hookOutput=$(docker exec "${system}_app" cat /tmp/hook-before 2>/dev/null)
if [[ "${hookOutput}" == "app docker single root" ]]; then
  pass "docker script got server name and parameters"
else
  fail "docker script output: ${hookOutput:-none}"
fi
hookOutput=$(docker exec "${system}_app" cat /tmp/hook-after 2>/dev/null)
if [[ "${hookOutput}" == "app nobody" ]]; then
  pass "docker script ran as docker user"
else
  fail "docker script with user output: ${hookOutput:-none}"
fi
if docker exec "${system}_db" test -e /tmp/hook-before 2>/dev/null; then
  fail "hook of app ran in db"
else
  pass "hook of app did not run in db"
fi
finishTest

startTest "volumes"
runAds "${projectPath}" volumes
assertExitCode 0
assertOutputContains "volume ${dataVolume}"
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
assertDataVolume 1
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
if [[ $(docker exec "${system}_db" cat /etc/skel/marker 2>/dev/null) == "kept" ]]; then
  pass "the new db container uses the kept data volume"
else
  fail "the new db container does not use the kept data volume"
fi
finishTest

startTest "erase"
runAds "${projectPath}" erase
assertExitCode 0
assertContainerMissing db
assertContainerMissing app
assertImageMissing "${system}/db:smoke"
assertImageMissing "${system}/app:smoke"
assertDataVolume 1
finishTest

# --- images without bash and other architectures ---

startTest "other images: rise"
otherServers='"alpine"'
if docker run --rm --platform linux/arm64 "arm64v8/${otherImageName}:${otherImageTag}" true >/dev/null 2>&1; then
  otherServers+=', "arm"'
else
  echo "  skipped arm64: no emulation for linux/arm64 available"
fi
mkdir -p "${otherPath}"
cat > "${otherPath}/ads.json" << EOF
{
  "global": {
    "systemName": "${otherSystem}"
  },
  "system": {
    "serverNames": [ ${otherServers} ]
  },
  "any": {
    "imageTag": "${otherImageTag}",
    "containerBootstrapCommand": "command -v bash >/dev/null || apk add --no-interactive bash shadow",
    "containerInstall": "uname -m > /tmp/installed"
  },
  "alpine": {
    "imageName": "${otherImageName}"
  },
  "arm": {
    "imageName": "arm64v8/${otherImageName}",
    "containerPlatform": "linux/arm64"
  }
}
EOF
runAds "${otherPath}" rise
assertExitCode 0
for otherServer in alpine arm; do
  if [[ "${otherServer}" == "arm" ]] && [[ "${otherServers}" != *arm* ]]; then
    continue
  fi
  otherContainer="${otherSystem}_${otherServer}"
  if [[ $(docker inspect --format '{{.State.Status}}' "${otherContainer}" 2>/dev/null) == "running" ]]; then
    pass "container ${otherContainer} is running"
  else
    fail "container ${otherContainer} is not running"
  fi
  if docker exec "${otherContainer}" sh -c 'command -v bash' >/dev/null 2>&1; then
    pass "bootstrap command installed bash in ${otherContainer}"
  else
    fail "bash is missing in ${otherContainer}"
  fi
  expectedArchitecture=$([[ "${otherServer}" == "arm" ]] && echo "aarch64" || docker run --rm "${otherImageName}:${otherImageTag}" uname -m)
  installedArchitecture=$(docker exec "${otherContainer}" cat /tmp/installed 2>/dev/null)
  if [[ "${installedArchitecture}" == "${expectedArchitecture}" ]]; then
    pass "container ${otherContainer} was installed on ${expectedArchitecture}"
  else
    fail "container ${otherContainer} was installed on ${installedArchitecture:-nothing}, expected ${expectedArchitecture}"
  fi
done
finishTest

startTest "other images: restart"
runAds "${otherPath}" restart
assertExitCode 0
if [[ $(docker inspect --format '{{.State.Status}}' "${otherSystem}_alpine" 2>/dev/null) == "running" ]]; then
  pass "container ${otherSystem}_alpine is running"
else
  fail "container ${otherSystem}_alpine is not running"
fi
finishTest

startTest "other images: purge"
runAds "${otherPath}" purge
assertExitCode 0
if docker ps -a -q --filter "label=com.docker.compose.project=${otherSystem}" | grep -q .; then
  fail "containers of ${otherSystem} still exist"
else
  pass "containers of ${otherSystem} were removed"
fi
finishTest

fi

# --- proxy and port registry ---

# a web server with HTTP on port 80 and HTTPS with an own certificate on port 443, reached only through the proxy; like
# real systems it is a cosyses/ubuntu container whose entrypoint runs the start scripts, so the servers run after every
# container start (and after the first restart following rise, because they are installed into the running container)
cat > "${testPath}/web.sh" << 'WEB'
#!/bin/bash -e
case "${1}" in
  install)
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq busybox openssl >/dev/null
    mkdir -p /srv
    echo "${2}" > /srv/index.html
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /srv/key.pem -out /srv/cert.pem -days 1 -subj "/CN=${2}.smoke.test" 2>/dev/null
    printf '#!/bin/bash\nbash /usr/local/bin/web.sh start\n' > /usr/local/lib/start/50-web.sh
    chmod +x /usr/local/lib/start/50-web.sh
    ;;
  start)
    busybox httpd -p 80 -h /srv
    nohup openssl s_server -quiet -www -accept 443 -cert /srv/cert.pem -key /srv/key.pem >/dev/null 2>&1 &
    ;;
esac
WEB

writeWebSystem()
{
  local name="${1}"
  local path="${2}"

  mkdir -p "${path}"
  jq -n --arg name "${name}" --arg port "${requestedPort}" --arg script "${testPath}/web.sh" '{
    global: {systemName: $name},
    system: {serverNames: ["web"]},
    web: {
      imageName: "cosyses/ubuntu",
      imageTag: "24.04",
      containerPorts: ["\($port):7000"],
      proxyHosts: ["\($name).smoke.test"],
      proxyHttpPort: "80",
      proxyHttpsPort: "443",
      skipPortsAvailable: "true",
      containerStartedCommand: "/usr/local/bin/started.sh",
      containerVolumes: ["\($script):/usr/local/bin/web.sh"],
      containerInstall: "bash /usr/local/bin/web.sh install \($name)"
    }
  }' > "${path}/ads.json"
}

proxyGet()
{
  curl -s -m 5 -H "Host: ${1}.smoke.test" "http://127.0.0.1:${proxyHttpPort}/"
}

# the subject of the certificate that the proxy passes through for a host name, waits until the server answers
proxyCertificate()
{
  local subject=
  local counter=0

  while [[ -z "${subject}" ]] && [[ "${counter}" -lt 20 ]]; do
    subject=$(echo | timeout 5 openssl s_client -connect "127.0.0.1:${proxyHttpsPort}" -servername "${1}.smoke.test" 2>/dev/null \
      | openssl x509 -noout -subject 2>/dev/null)
    if [[ -z "${subject}" ]]; then
      sleep 1
    fi
    counter=$((counter + 1))
  done
  echo "${subject}"
}

assertProxyServes()
{
  local name="${1}"

  if [[ $(proxyGet "${name}") == "${name}" ]]; then
    pass "proxy serves http for ${name}.smoke.test"
  else
    fail "proxy does not serve http for ${name}.smoke.test: $(proxyGet "${name}")"
  fi
  if [[ $(proxyCertificate "${name}") == *"CN = ${name}.smoke.test"* ]]; then
    pass "proxy passes https through to the certificate of ${name}.smoke.test"
  else
    fail "proxy does not pass https through for ${name}.smoke.test: $(proxyCertificate "${name}")"
  fi
}

assertHostPort()
{
  local name="${1}"
  local expected="${2}"
  local hostPort

  hostPort=$(docker inspect --format '{{ (index (index .HostConfig.PortBindings "7000/tcp") 0).HostPort }}' "${name}_web" 2>/dev/null)
  if [[ "${hostPort}" == "${expected}" ]]; then
    pass "${name}_web publishes container port 7000 on host port ${expected}"
  else
    fail "${name}_web publishes container port 7000 on host port ${hostPort:-none}, expected ${expected}"
  fi
}

writeWebSystem "${systemA}" "${testPath}/proxy-a"
writeWebSystem "${systemB}" "${testPath}/proxy-b"

# a container created before its server used the proxy publishes the web port itself and has to keep working that way
systemLegacy="${system}l"
writeWebSystem "${systemLegacy}" "${testPath}/proxy-legacy"
jq --arg port "${proxyHttpPort}" '.web.containerPortsFixed = "true" | .web.containerPorts = ["\($port):80"]' \
  "${testPath}/proxy-legacy/ads.json" > "${testPath}/proxy-legacy/ads.json.tmp"
mv "${testPath}/proxy-legacy/ads.json.tmp" "${testPath}/proxy-legacy/ads.json"

startTest "proxy: container that publishes the proxy ports itself"
runAds "${testPath}/proxy-legacy" rise
assertExitCode 0
assertOutputContains "publishes the ports of the proxy itself"
if [[ $(docker inspect --format '{{.State.Status}}' "${systemLegacy}_web" 2>/dev/null) == "running" ]]; then
  pass "${systemLegacy}_web is running with its own ports"
else
  fail "${systemLegacy}_web is not running"
fi
if docker inspect "${proxySystem}_proxy" >/dev/null 2>&1 || [[ -f "${userPath}/var/proxy/${proxySystem}/routes/${systemLegacy}_web.yml" ]]; then
  fail "proxy or route was created for a container that publishes the proxy ports"
else
  pass "no proxy and no route for a container that publishes the proxy ports"
fi
runAds "${testPath}/proxy-legacy" purge
assertExitCode 0
finishTest

startTest "proxy: first system"
runAds "${testPath}/proxy-a" rise
assertExitCode 0
runAds "${testPath}/proxy-a" restart
assertExitCode 0
if [[ $(docker inspect --format '{{.State.Status}}' "${proxySystem}_proxy" 2>/dev/null) == "running" ]]; then
  pass "proxy ${proxySystem}_proxy was started by the first system"
else
  fail "proxy ${proxySystem}_proxy is not running"
fi
assertProxyServes "${systemA}"
assertHostPort "${systemA}" "${requestedPort}"
finishTest

startTest "proxy: second system on the same ports"
runAds "${testPath}/proxy-b" rise
assertExitCode 0
runAds "${testPath}/proxy-b" restart
assertExitCode 0
assertProxyServes "${systemB}"
assertProxyServes "${systemA}"
assertHostPort "${systemB}" "$((requestedPort + 1))"
runAds "${testPath}/proxy-b" ports
assertOutputContains "$((requestedPort + 1))"
finishTest

startTest "proxy: status and hosts"
runAds "${testPath}" proxy status
assertExitCode 0
assertOutputContains "${systemA}.smoke.test"
assertOutputContains "${systemB}.smoke.test"
runAds "${testPath}" proxy hosts
assertOutputContains "127.0.0.1 ${systemA}.smoke.test"
finishTest

startTest "connect"
docker run -d --name "${toolContainer}" --label "com.docker.compose.project=${toolContainer}" busybox:1.36 sleep 600 >/dev/null 2>&1 \
  || docker run -d --name "${toolContainer}" --label "com.docker.compose.project=${toolContainer}" ubuntu:24.04 sleep 600 >/dev/null
runAds "${testPath}/proxy-a" connect "${toolContainer}"
assertExitCode 0
if [[ $(docker exec "${toolContainer}" wget -qO- http://web/ 2>/dev/null) == "${systemA}" ]]; then
  pass "tool container reaches the server by its name"
else
  fail "tool container does not reach http://web/ of ${systemA}"
fi
runAds "${testPath}/proxy-a" connect "${toolContainer}" --disconnect
assertExitCode 0
finishTest

startTest "proxy: restart"
runAds "${testPath}/proxy-b" restart
assertExitCode 0
assertProxyServes "${systemB}"
finishTest

startTest "proxy: removed system"
runAds "${testPath}/proxy-a" purge
assertExitCode 0
if [[ ! -f "${userPath}/var/proxy/${proxySystem}/routes/${systemA}_web.yml" ]] && [[ $(curl -s -o /dev/null -w "%{http_code}" -m 5 -H "Host: ${systemA}.smoke.test" "http://127.0.0.1:${proxyHttpPort}/") == "404" ]]; then
  pass "route of ${systemA} was removed"
else
  fail "route of ${systemA} still exists"
fi
assertProxyServes "${systemB}"
finishTest

startTest "port registry keeps ports"
runAds "${testPath}/proxy-b" purge
assertExitCode 0
runAds "${testPath}/proxy-b" rise
assertExitCode 0
runAds "${testPath}/proxy-b" restart
assertExitCode 0
# the requested port is free again, but the system keeps the port it was assigned
assertHostPort "${systemB}" "$((requestedPort + 1))"
assertProxyServes "${systemB}"
runAds "${testPath}/proxy-b" purge
finishTest

startTest "proxy: remove"
runAds "${testPath}" proxy remove
assertExitCode 0
if docker inspect "${proxySystem}_proxy" >/dev/null 2>&1; then
  fail "proxy container still exists"
else
  pass "proxy container was removed"
fi
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
