# Dotfiles

Personal NixOS and nix-darwin machine config.

## Bootstrap

Install Nix first, then clone the repo to `~/.config/dotfiles`. Home Manager
links config files from there into your home directory, and activation stops
if the checkout is anywhere else.

```bash
git clone <repo> ~/.config/dotfiles
cd ~/.config/dotfiles
```

If `nix` is not installed, `./check` and `./install` exit early and point to:

`https://github.com/DeterminateSystems/nix-installer`

## Check

`./check` builds the current machine's Nix config without switching generations.

```bash
./check
```

On every push, [CI](.github/workflows/fleet.yml) builds each host and runs the flake checks on GitHub-hosted runners.

Machine selection is automatic:

- on macOS, via `scutil --get LocalHostName`
- on NixOS, via the static hostname from `hostnamectl` or `/etc/hostname`

Those names must match the flake host names. Multiple names may point to the same configuration when a machine has an alias.

## Update

`./update` reports the package and container image updates available and
changes nothing. `./update --apply` updates every flake input, regenerates
`agents/skills/generated/`, and bumps the packages in `nix/packages/` and the
`name:tag@sha256:…` images under `nix/hosts/`. Run `./check` afterwards.

```bash
./update --apply
```

It never prompts and needs no terminal. Each change prints as one
`name old -> new` line on stdout, followed by `note:` lines worth a look (a
major version, or an image whose newest tag is ambiguous). It exits 1 if
anything failed and keeps the updates that worked. The GitHub token comes from
`GH_TOKEN`, `GITHUB_TOKEN` or `gh auth token`; `nix`, `git`, `curl` and `jq`
must be on `PATH`, and `skopeo` comes from the pinned nixpkgs.

Inputs whose URL names a revision do not move: `hermes-agent` is held on
purpose (see TODO.md), and `hex` moves only with its package.

## Install

`./install` switches the current machine to a new generation with the appropriate rebuild command for the live system.

```bash
./install
```

On a Mac without nix-darwin, the installer builds the selected configuration from this flake and uses its pinned `darwin-rebuild` to perform the first activation. Only Nix itself must already be installed.

## El Toro

`eltoro` is a remote NixOS LXC. Build it locally and activate it on the
container over SSH:

```bash
./install-eltoro
```

See [El Toro](docs/eltoro.md) for onboarding, settings, and the host-side
firewall setup.

## Secrets

Secrets are encrypted with fnox in `secrets/fnox.toml` and decrypted on each
host at boot. See [Secrets](docs/secrets.md).

## Rex

For the Rex macOS client setup, see [Rex](docs/rex.md).

## Config files

Home Manager links config files such as `hypr/*.lua`, `quickshell/`, `bin/*`
and the KDE files in `kde/` from the checkout, not from the Nix store, so edits
take effect without a rebuild and programs that rewrite their own config can.
Adding or removing a link takes `./install`. A new file in `bin/`,
`agents/skills/personal/`, `agents/skills/generated/`, `hypr/` (`*.lua`) or
`quickshell/` gets its link once Git tracks it; the other links are listed in
`nix/modules/home/workstation.nix` (both workstations),
`nix/hosts/scylla/home.nix` and `nix/hosts/carters-macbook-pro/default.nix`.
