# Dotfiles

## Installation

- Clone the repo into `~/.dotfiles` with `git clone --recurse-submodules ~/.dotfiles`
- Install the [nix package manager](https://nixos.org/nix/) (usually with `curl -L https://nixos.org/nix/install | sh`, requires `curl` and `xz` from `xz-utils`)

* [`install.conf.yaml`](./install.conf.yaml): what files go where.
* [`flake.nix`](./flake.nix): nix-darwin config, shared packages, and task runners.
* Common commands:
  * `nix run .#install-files`
  * `nix run .#install-macos`
  * `nix run .#update-macos`
  * `nix run .#update-dotbot`
