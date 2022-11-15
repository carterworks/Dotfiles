# Dotfiles


## Includes

- fish shell
- helix
- git
- nix-darwin
- tmux
- starship prompt

## Installation

1. Install the dependencies
    - [nix package manager](https://nixos.org/nix/) (usually with `curl -L https://nixos.org/nix/install | sh`, requires `curl` and `xz` from `xz-utils`)
    - [nix-darwin](https://github.com/LnL7/nix-darwin#install) (if you are own MacOS)
2. Open a shell with chezmoi and git
    - `nix shell nixpkgs#chezmoi nixpkgs#git -c "chezmoi init --apply carterworks"`
    - `nix-shell -p chezmoi git --command "chezmoi init --apply carterworks"` for older systems
3. When you want to make changes, do so with `chezmoi edit $FILE_PATH`

## Helpful commands

These are ripped straight from the [chezmoi documentation](https://chezmoi.oi/user-guide/daily-operations)

### Pull the latest changes from your repo and see what would change, without actually applying the changes

```bash
chezmoi git pull -- --autostash --rebase && chezmoi diff
```

and then apply them if they look good with

```bash
chezmoi apply
```
