# Dotfiles

## Installation

Clone the repo into `~/.dotfiles` with `git clone --recurse-submodules`
 

## Includes

- vim
- gitconfig
- spacemacs
- tmux
- sshconfig

## Other

### Update Dotbot

`git submodule update --remote dotbot`

> Setting up Dotbot as a submodule or subrepo locks it on the current version. You can upgrade Dotbot at any point. If using a submodule, run `git submodule update --remote dotbot`, substituting dotbot with the path to the Dotbot submodule; be sure to commit your changes before running `./install`, otherwise the old version of Dotbot will be checked out by the install script. If using a subrepo, run `git fetch && git checkout origin/master` in the Dotbot directory.
