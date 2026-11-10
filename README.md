# Dotfiles

One Nix flake for four machines.

| Host | What | Configuration | Updated by |
|---|---|---|---|
| `scylla` | NixOS desktop | `nix/hosts/scylla/` | `./install` on it |
| `carters-macbook-pro` | nix-darwin laptop (employer-owned) | `nix/hosts/carters-macbook-pro/` | `./install` on it |
| `prostagma` | NixOS LXC on Proxmox: media, photos, SSO, binary cache | `nix/hosts/prostagma/` | itself, nightly |
| `eltoro` | NixOS LXC on Proxmox: a fenced Hermes agent | `nix/hosts/eltoro/` | itself, nightly |

Shared modules are in `nix/modules/`: `nixos/common.nix` for every NixOS
host, `nixos/server.nix` for the two servers.

## How a change reaches the hosts

1. Push. [CI](.github/workflows/fleet.yml) builds every host and runs the flake
   checks.
2. On `main`, CI pushes what it built to the private
   [binary cache](docs/binary-cache.md) on prostagma, then moves the `release`
   branch to that commit. Until the cache's secrets are set, it skips both.
3. A nightly job runs `./update --apply`, merges the result into `main` once
   everything is green, and moves `release` to it once it is cached
   ([CI](docs/ci.md)).
4. prostagma and eltoro switch to `release` every night
   ([Server auto-upgrade](docs/auto-upgrade.md)). This stays off until the
   cache key is set.
5. On scylla and the Mac, run `./install`.

`./drift [ref]`, run from scylla, shows whether each NixOS host runs what
`release` (or `ref`) says it should, and when it last switched.

## Deploy by hand

```bash
./install                     # this machine: scylla or the Mac
./install prostagma           # build here, activate there as carter with sudo
./install eltoro              # build here, activate there as root
./install eltoro dry-activate # any nixos-rebuild action; the default is switch
```

A remote deploy has the target fetch from its own caches and receives only the
rest over SSH. As with `./update`, the GitHub token comes from `GH_TOKEN`,
`GITHUB_TOKEN` or `gh auth token`; Nix gets it through `NIX_CONFIG`, never on a
command line, and root never gets it. `PROSTAGMA_HOST` and `ELTORO_HOST` override the SSH targets.

To build a host without switching to it:

```bash
nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
```

## Update

`./update` reports the package and container image updates available and
changes nothing. `./update --apply` updates every flake input, regenerates
`agents/skills/generated/`, and bumps the packages in `nix/packages/` and the
`name:tag@sha256:…` images under `nix/hosts/`.

It never prompts and needs no terminal. Each change prints as one
`name old -> new` line, followed by `note:` lines worth a look (an image held
back from a new major version, or one whose newest tag is ambiguous). It exits
3 if some items failed and keeps the updates that worked, and 1 if the updater
itself failed. The GitHub token comes from
`GH_TOKEN`, `GITHUB_TOKEN` or `gh auth token`; `nix`, `git`, `curl` and `jq`
must be on `PATH`.

An image moves only within its major version, because a new major usually
migrates the application's data one way; below 1.0 the second number counts
as the major. Take a new major deliberately with `./update --apply --majors`
and review that commit by hand.

Inputs whose URL names a revision do not move: `hermes-agent` is held on
purpose (see TODO.md), and `hex` moves only with its package.

## Bootstrap

Every machine needs this repository at `~/.config/dotfiles`: Home Manager links
config files from there, and activation stops if the checkout is anywhere
else. `./install` picks the configuration by the machine's name
(`scutil --get LocalHostName` on macOS, the static hostname on NixOS), which
must match a flake host.

- **Mac**: install Nix with the
  [Determinate installer](https://github.com/DeterminateSystems/nix-installer),
  clone, and run `./install`. Without nix-darwin, it builds the configuration
  and activates it with its own pinned `darwin-rebuild`.
- **scylla**: install NixOS, clone, and, on new hardware, replace
  `nix/hosts/scylla/hardware.nix` with `nixos-generate-config --show-hardware-config`.
  Then `./install`.
- **A server**: create the container from the NixOS LXC template on Proxmox
  (`docs/eltoro.md` has the `pct create` line and the `/dev/net/tun`
  passthrough Tailscale needs) and authorize the admin key for root on it.
  A rebuilt server first gets its old SSH host keys back, so it can read its
  secrets ("Rebuilding a host with its old identity" in
  [Secrets](docs/secrets.md)). Then, from scylla:
  `PROSTAGMA_HOST=root@<address> ./install prostagma`, or
  `ELTORO_HOST=root@<address> ./install eltoro`. Finally run `tailscale up` on
  the server; no auth key is stored.

## By hand, by the owner

- Create the binary cache and set its key, the CI token, the GitHub
  Environment and the tailnet policy ([Binary cache](docs/binary-cache.md)).
  Setting the key also turns on server auto-upgrades.
- Before that, deploy eltoro's chain-based fence by hand ("Deploying fence
  changes" in [El Toro](docs/eltoro.md)).
- Run `./install` on scylla and the Mac.
- Check `systemctl --failed` on the servers, or run `./drift`: a failed
  auto-upgrade notifies nobody.
- Add, rotate and enrol secrets ([Secrets](docs/secrets.md)).
- Approve the Beszel Service, make the agents' tokens and set the hub's key
  ("First deployment" in [Monitoring](docs/monitoring.md)).

## Runbooks

- [Binary cache](docs/binary-cache.md)
- [Server auto-upgrade](docs/auto-upgrade.md)
- [Secrets](docs/secrets.md): encrypted with fnox in `secrets/fnox.toml`
- [El Toro](docs/eltoro.md): onboarding, settings, the egress fence
- [Monitoring](docs/monitoring.md): the Beszel hub on prostagma and its agents
- [Rex](docs/rex.md): the macOS client

## Config files

Home Manager links config files such as `hypr/*.lua`, `quickshell/`, `bin/*`
and the KDE files in `kde/` from the checkout, not from the Nix store, so edits
take effect without a rebuild and programs that rewrite their own config can.
Adding or removing a link takes `./install`. A new file in `bin/`,
`agents/skills/personal/`, `agents/skills/generated/`, `hypr/` (`*.lua`) or
`quickshell/` gets its link once Git tracks it; the other links are listed in
`nix/modules/home/workstation.nix` (both workstations),
`nix/hosts/scylla/home.nix` and `nix/hosts/carters-macbook-pro/default.nix`.
