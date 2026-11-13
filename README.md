<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/anodosys-logo-dark.svg">
    <img src="logo/anodosys-logo.svg" alt="Anodosys" width="473">
  </picture>
</p>

<p align="center">Step pipelines across Docker containers.</p>

Anodosys builds and runs systems of several Docker containers that are described in one `ads.json`. Its actions are
pipelines of steps that move between the containers in a fixed order, for example installing something in the first
container, then in the second one and afterwards again in the first one. Servers run in waves: as soon as the servers
they depend on are done, they run in parallel.

# Installation

```
curl -fsSL https://raw.githubusercontent.com/anodosys/app/master/setup.sh | sudo bash
```

Supported are Ubuntu, Debian and Fedora (and distributions based on them). The setup installs the required packages
with `apt` or `dnf`, and `jcp` and `j2v` from their GitHub repositories if they are missing. Docker has to be installed
separately.

# Update

```
sudo ads update                                 # update to the latest release
sudo ads update --applicationVersion <version>  # install a specific release
sudo ads update --force                         # re-install the release
ads version                                     # show the installed version
```

Releases are installed in `/usr/local/lib/anodosys/<version>`, and `current` links to the active one. An update keeps the active and the previous release and removes older ones.

# Logs

Every run of a system action (for example `ads rise` or `ads start`) is appended to a log file per system:

```
~/.anodosys/var/log/<systemName>.log
```

Each run starts with a line containing the time, the command and the directory. The lines are the same as in the
terminal, with the `[system] [server]` prefix, but without colors and other terminal control codes. Progress bars
(for example from Composer) are reduced to their last state. When a log file is larger than
10 MB, it is renamed to `<systemName>.log.1` at the start of the next run, replacing an older one.

```
ads log                 # show the last 100 lines of the log of the system in the current directory
ads log --lines 500     # show the last 500 lines
ads log --follow        # keep showing new lines while a run is in progress
ads log <systemName>    # show the log of a registered system from any directory
```

Actions that only show information (`config`, `status`, `log`, ...) or open a shell (`bash`, `cmd`, ...) are not
logged.

# Listing systems

`ads list` shows every known system as started, partly started (with the number of running containers), stopped or
not created. The state is read from Docker each time and not stored. Containers belong to a system by the label
`anodosys.system`. Containers created before that label existed count if their `com.docker.compose.project` label is a
known system and they have no `com.docker.compose.version` label, so containers of docker compose or ddev never count,
even with the same project name. Systems become known when they are created and are kept in `~/.anodosys/systems.json`
with their configuration file, which `--systemName` and `ads-jump` use.

# Running several systems at the same time

## Host names instead of ports 80 and 443

A server that declares host names is reached through a shared proxy instead of publishing ports 80 and 443 itself:

```json
"webserver": {
  "proxyHosts": ["{appHostName}"],
  "proxyHttpPort": "80",
  "proxyHttpsPort": "443"
}
```

The proxy (`anodosys_proxy`, Traefik installed with `cosyses Traefik 3.7`) owns the host ports 80 and 443 and routes by
host name. HTTP goes to `proxyHttpPort` of the container (default 80, empty for none). HTTPS is passed through
unchanged to `proxyHttpsPort` (default none) and routed by the server name of the TLS connection, so the containers keep
their own certificates. The proxy is created with the first system that uses `proxyHosts`, and every container with
host names joins its network. Web tools work the same way, for example `"proxyHosts": ["mail.{appHostName}"]` with
`"proxyHttpPort": "1080"`.

```
ads proxy status    # show the proxy and the host names of all systems
ads proxy hosts     # print the host names that are missing in /etc/hosts (and the Windows hosts file in WSL)
ads proxy start     # also: stop, restart, remove
```

The host names have to point to `127.0.0.1` in the hosts file of the machine that runs the browser.

The Traefik dashboard of the proxy is at http://anodosys.localhost/ and shows every route, its host names and the
container it leads to. Browsers resolve names below `.localhost` without a hosts entry. A proxy created before the
dashboard existed gets it with `ads proxy update` (or `ads proxy restart`), which installs Traefik again in the running
container; containers connected to the proxy stay connected.

## Fixed host ports for everything else

Ports that cannot be routed by name, such as MySQL or Redis, are still published with `containerPorts`, but the host
port is a request: the first system that requests a host port keeps it, and a later system that requests the same port
gets the next free one. Every assignment is stored in `~/.anodosys/var/ports.json` and kept, also when containers are
removed and created again, so tools configured for a port keep working. `ads ports` shows the assigned ports. A server
with `"containerPortsFixed": "true"` always publishes the configured ports.

## Tools in containers

A container that is not part of a system, for example a database tool, can join the network of a system and reach its
servers by name and container port (for example `database:3306`), without any host port:

```
ads connect <container>                 # run in the system directory
ads connect <container> --disconnect
```

# Data that outlives its container

Everything a container writes stays in the container: removing it (`remove`, `purge`, `erase`) or creating it again
loses that data. A path whose data has to stay, for example the files of a database, is kept in a data volume:

```json
"database": {
  "containerDataVolumes": ["data:/var/lib/mysql"]
}
```

Every entry `name:/path/in/container` becomes the named Docker volume `<system>_<server>_<name>`. When it is created,
Docker fills it with what the image has at that path, so a database that was initialized in the image starts with its
initial files. `remove`, `purge` and `erase` keep data volumes, and a container created again mounts the same volume
with the data. `ads volumes` lists them; they are only deleted by hand with `docker volume rm <name>`. Images built
with `image` do not contain the data of a data volume.

A container that already exists does not get a data volume afterwards: back up its data, create it again and restore
the data into the volume.

# Extensions

Extensions add actions, constructs, library functions, host tools and configuration to Anodosys. They are managed with `ads extension` (or the equivalent `ads-ext`):

```
ads extension add    <name> git <url>   # clone and install an extension
ads extension update <name>             # pull the latest version and re-install it
ads extension reset  <name>             # re-install from the downloaded copy, discarding local changes
ads extension remove <name>             # uninstall the extension
```

The git clone lives in `~/.anodosys/var/extension/<name>`. Its content (without `.git`) is synced to:

- `~/.anodosys/extension/<name>` when run as a normal user
- `/usr/local/lib/anodosys/extension/<name>` when run as root, shared by all installed releases (`extension/<name>` in a local checkout)

Every subdirectory of these two directories is loaded as an extension on each run, so an extension can also be created by hand there. User extensions take precedence over installed ones.

An extension can contain:

```
<name>/
  action/system/<action>.sh    # system action: ads <action>
  action/server/<action>.sh    # server action: ads <action> or ads <name>:<action>
  action/server/<action>.txt   # optional description shown in the usage output
  construct/<type>.sh          # ads construct <type>
  lib/*.sh                     # functions available to all scripts
  host/                        # tools added to PATH by sourcing host.sh
  configuration/               # configuration fragments
  script/                      # scripts used by the configuration
```

Each extension directory is passed to `jcp process` as a parameter named after the extension, so the system configuration can use the extension's `configuration/` and `script/` files.
