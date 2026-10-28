# Rex

## macOS client

`nix/packages/rex-client.nix` installs the preview app. It is included in the
macOS configuration, but its download and update-feed locations are private.
The derivation records only a filename and hash using `requireFile`.

Store source locations in `~/.config/dotfiles-private/sources.json`, outside
this repository, with permissions `0600`. Override that path with
`DOTFILES_PRIVATE_SOURCES_FILE` if needed. Do not copy real values into these
docs, Nix expressions, or `flake.lock`.

```json
{
  "rex": {
    "clientFeedUrl": "INSERT_PRIVATE_SPARKLE_FEED_URL",
    "clientUrlTemplate": "INSERT_PRIVATE_DMG_URL_WITH_{version}_PLACEHOLDER",
    "serverFlakeUrl": "INSERT_PRIVATE_PREVIEW_FLAKE_URL"
  }
}
```

The updater replaces `{version}` in the DMG URL template with the pinned
version and build number, such as `0.1.0-1541`.

```bash
./update --fetch rex-client
./install
```

`--fetch` verifies the pinned hash and imports the installer into the local
Nix store without writing source URLs to a derivation or updating any files.
Use it on each Mac that needs the installer. `./update --apply` checks the
private feed, caches new installers, and updates only the version and hash in
Git. Without the private manifest, Rex update discovery is skipped, while
the other packages continue normally. Builds need only the cached installer,
not the manifest.

New local terminals launch Fish using the same Nix executable as Ghostty,
without changing the account's login shell. This is managed in
`nix/users/carter/darwin.nix` through Rex's macOS preference
`Workspace.terminalStartupCommand`, not through `init.lua`. It applies to
new local tabs and splits; existing terminals and remote hosts are unchanged.

Interactive Fish, Bash, and Zsh startup restores a nonempty `REX_BIN_DIR`
to the front of `PATH` after Nix's shell initialization. This keeps the CLI
matched to its server without adding empty path entries outside Rex. See the
[upstream PATH guidance](https://www.superlogical.com/rex/docs/automate/cli#path).

## Configuration

`rex/init.lua` preserves Rex's defaults and is linked to
`~/.config/rex/init.lua` by Dotbot. Edit that file to customize Rex using the
[configuration guide](https://www.superlogical.com/rex/docs/customize/config).
If `XDG_CONFIG_HOME` or `REX_CONFIG` is set, Rex may read a different path.

Validate changes with `rex config check`, then apply them with
`rex config reload` on the machine running the server. Rex does not watch
the file for changes. The shared Linux server instead reads the `rex`
account's `/var/lib/rex/.config/rex/init.lua`.

## Linux server (waiting for testing access)

Register for Linux in Discord's `#alpha-registration`. All documented Linux
downloads currently require a package token. Do not put that token in a Nix
file, URL, flake input, Git, or the Nix store.

The repository already includes:

- A commented external-path `rex` input in `flake.nix`.
- `nix/packages/rex-server.nix`, which exposes the upstream default package as
  `.#packages.x86_64-linux.rex-server` once the input is present.
- `nix/modules/rex.nix`, imported on Scylla and Prostagma, but disabled by
  default. Enabling it without the input produces an actionable assertion.

The wrapper uses the official **shared-server NixOS module**, not a personal
Home Manager service. Programs launched inside Rex run as the dedicated `rex`
account, not as Carter. Carter is added to the `rex` group when enabled.
The wrapper gives the `rex` account an interactive Bash shell so its terminals
do not immediately exit through `nologin`.
Anyone in that group has full access to the shared server and its sessions.

### 1. Store the token outside the repository

On each Linux host that will download Rex, create or edit the Nix netrc file:

```bash
sudo mkdir -p /etc/nix
sudo touch /etc/nix/netrc
sudo chmod 600 /etc/nix/netrc
sudoedit /etc/nix/netrc
```

Add this entry, replacing the placeholder with your token. Preserve entries
for other services, and update any existing Rex entry rather than duplicating it.

```netrc
machine INSERT_HOST_FROM_YOUR_PRIVATE_SERVER_FLAKE_URL
login rex
password INSERT_YOUR_REX_PACKAGE_TOKEN_HERE
```

The enabled wrapper sets `nix.settings.netrc-file = "/etc/nix/netrc"`.
The file is mutable and root-readable; Nix receives its path, never its contents
as a Nix value.

**If updating the lock on this Mac with Determinate Nix:** its authentication
is separate. Put the entry in `/etc/determinate/rex.netrc` instead, and add
that path to `authentication.additionalNetrcSources` in
`/etc/determinate/config.json`. Merge with existing configuration rather than
replacing it. Follow the [upstream Determinate instructions](https://www.superlogical.com/rex/docs/linux/installation)
to reload the daemon. Determinate merges those sources into
`/nix/var/determinate/netrc`, which is readable by every local user; do not
edit the generated file. Tokens must be configured on build/download hosts,
not just the machine editing this repository.

### 2. Cache, activate, and lock the input

Set `rex.serverFlakeUrl` in the same private source manifest. Once Nix's
authentication is configured, cache the flake outside the repository:

```bash
./update --fetch rex-server
```

This creates an indirect GC root at
`${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-private/rex-flake`. No private
URL is written to the repository. If bootstrap authentication on standard
Nix requires root, preserve the calling user's private paths explicitly:

```bash
sudo env \
  DOTFILES_PRIVATE_SOURCES_FILE="$HOME/.config/dotfiles-private/sources.json" \
  XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
  NIX_CONFIG='netrc-file = /etc/nix/netrc' \
  ./update --fetch rex-server
```

Uncomment the placeholder in `flake.nix`, replacing the path with that
external GC root's **absolute** path on the machine that manages the lock:

```nix
rex.url = "path:/absolute/path/to/private/rex-flake";
```

Then lock and archive it:

```bash
nix flake lock
nix flake archive
```

The external path is local state: every machine evaluating this input must
have that same path containing the exact pinned flake, or receive its archived
source through your private deployment process. Do not fetch a different
release on another host and assume it matches the root lock. Multi-host
deployment of the gated input remains unvalidated until testing access is
available.

Inspect the lock before committing it: neither this input nor any transitive
input may contain a private download URL. If upstream introduces private URL
inputs, stop and keep the lock change local until those are handled too.
The upstream flake's own source and metadata may contain private locations
in the local Nix store; do not publish those sources or build logs. Its
private source remains outside this Git repository.

### 3. Enable the service per host

Add this inside the configuration attribute set in
`nix/machines/scylla.nix` and/or `nix/machines/prostagma.nix`:

```nix
dotfiles.rex.enable = true;
```

On the target Linux host:

```bash
nix build --no-link .#rex-server
./check
./install
sudo systemctl status rex.service
sudo journalctl -u rex.service -n 50 --no-pager
```

Log out and back in so Carter's new group membership takes effect. Verify:

```bash
rex -S /run/rex/server.sock ls
```

This remains local-only by default: it opens no firewall ports and enables no
anonymous listener. For access from the macOS client, separately configure an
authenticated listener using the upstream [Remote Access guide](https://www.superlogical.com/rex/docs/linux/remote-access).

### Updates

After the input is activated, `./update --apply` refreshes the external Rex
flake from the private manifest before the existing `nix flake update` step.
The root lock records the local source pin, not the private URL.
If standard Nix cannot read the root-only netrc during an input fetch, run
the updater with the explicit private-manifest and data paths as shown above.
For a Rex-only update, run `./update --fetch rex-server`, then
`nix flake update rex` on the machine whose external path is in the input.

Review the lock for private URLs, then run `./check` and `./install` on each host.
Shared-server restarts/upgrades end its sessions; plan updates accordingly.

The real upstream module and binary cannot be validated until a token is
available. Repository tests cover the wrapper's disabled, missing-input, and
enabled behavior using a stub upstream module; they do not prove upstream
compatibility.
