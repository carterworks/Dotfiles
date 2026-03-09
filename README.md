# Dotfiles

Personal NixOS and nix-darwin machine config.

## Install

Install Nix first, then clone the repo and run the installer.

```bash
git clone <repo> ~/.config/dotfiles
cd ~/.config/dotfiles
./install
```

If `nix` is not installed, `./install` exits early and points to the official installer:

`https://nixos.org/download/`

## Dotbot

`./install` runs Dotbot from the pinned `nixpkgs` input in `flake.lock`, so Dotbot updates now come from your normal flake input updates instead of a submodule bump.

```bash
nix flake update
```
