# Dotfiles

Personal machine config. Nix handles system state. Dotbot handles symlinks.

## Install

Clone with submodules, then run the installer.

```bash
git clone --recurse-submodules <repo> ~/.dotfiles
cd ~/.dotfiles
./install
```

If you also want the Darwin system config, install the [Nix package manager](https://nixos.org/nix/) and use the flake entrypoints from this repo.

## Layout

- `install.conf.yaml` says what Dotbot links where.
- `flake.nix` holds nix-darwin config, shared packages, and machine entrypoints.
- `opencode/` holds shared agent config reused by other tools.

## Common Commands

```bash
nix run .#install-files
nix run .#install-macos
nix run .#update-macos
nix run .#update-dotbot
```

## Update Dotbot

Pull the latest upstream Dotbot, then commit the submodule bump.

```bash
git submodule update --remote dotbot
git submodule update --init --recursive dotbot
git add dotbot
git commit -m "[dotbot] update submodule"
```

`./install` pins Dotbot to the committed submodule revision, so commit the bump before relying on it elsewhere.
