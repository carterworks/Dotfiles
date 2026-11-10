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
    "clientUrlTemplate": "INSERT_PRIVATE_DMG_URL_WITH_{version}_PLACEHOLDER"
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
`nix/hosts/carters-macbook-pro/default.nix` through Rex's macOS preference
`Workspace.terminalStartupCommand`, not through `init.lua`. It applies to
new local tabs and splits; existing terminals and remote hosts are unchanged.

Interactive Fish, Bash, and Zsh startup restores a nonempty `REX_BIN_DIR`
to the front of `PATH` after Nix's shell initialization. This keeps the CLI
matched to its server without adding empty path entries outside Rex. See the
[upstream PATH guidance](https://www.superlogical.com/rex/docs/automate/cli#path).

## Configuration

`rex/init.lua` preserves Rex's defaults and is linked to
`~/.config/rex/init.lua` by Home Manager. Edit that file to customize Rex using the
[configuration guide](https://www.superlogical.com/rex/docs/customize/config).
If `XDG_CONFIG_HOME` or `REX_CONFIG` is set, Rex may read a different path.

Validate changes with `rex config check`, then apply them with
`rex config reload` on the machine running the server. Rex does not watch
the file for changes.
