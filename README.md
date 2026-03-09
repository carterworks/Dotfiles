# Dotfiles

Personal NixOS and nix-darwin machine config.

## Install

Clone with submodules, then run the installer.

```bash
git clone --recurse-submodules <repo> ~/.config/dotfiles
cd ~/.config/dotfiles
./install
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
