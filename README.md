# Dotfiles

Personal NixOS and nix-darwin machine config.

## Bootstrap

Install Nix first, then clone the repo.

```bash
git clone <repo> ~/.config/dotfiles
cd ~/.config/dotfiles
```

If `nix` is not installed, `./check` and `./install` exit early and point to:

`https://github.com/DeterminateSystems/nix-installer`

## Check

`./check` dry-runs Dotbot, then builds the current machine's Nix config without switching generations.

```bash
./check
```

Machine selection is automatic:

- on macOS, via `scutil --get LocalHostName`
- on NixOS, via the static hostname from `hostnamectl` or `/etc/hostname`

Those names must match the flake host names.

## Install

`./install` runs Dotbot, then switches the current machine to a new generation with the appropriate rebuild command for the live system.

```bash
./install
```

## Dotbot

`./check` and `./install` run Dotbot from the pinned `nixpkgs` input in `flake.lock`, so Dotbot updates come from normal flake input updates instead of a submodule bump.

```bash
nix flake update
```
