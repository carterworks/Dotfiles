# Dotfiles

## Installation

- Clone the repo into `~/.dotfiles` with `git clone --recurse-submodules ~/.dotfiles`
- Install the [nix package manager](https://nixos.org/nix/) (usually with `curl -L https://nixos.org/nix/install | sh`, requires `curl` and `xz` from `xz-utils`)
- Install [mise-en-place](https://mise.jdx.dev/)

* [`install.conf.yaml`](./install.conf.yaml): what files go where.
* [`flake.nix`](./flake.nix): A nix flake for system-level packages and macOS configurations.
* [`mise.toml`](./mise.toml): project-level packages and tasks, like `mise run install` or `mise run install-macos`. Use `mise tasks ls` to list out all tasks.
