# Installation

```
wget --no-cache -q -O - https://raw.githubusercontent.com/anodosys/app/master/setup.sh | bash
```

# Update

```
sudo ads update                                 # update to the latest release
sudo ads update --applicationVersion <version>  # install a specific release
sudo ads update --force                         # re-install the release
ads version                                     # show the installed version
```

Releases are installed in `/usr/local/lib/anodosys/<version>`, and `current` links to the active one. An update keeps the active and the previous release and removes older ones.

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
