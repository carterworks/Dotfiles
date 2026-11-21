# nix-darwin's /etc/zshrc runs an uncached compinit, bashcompinit and promptinit
# (~150 ms) on hosts not yet switched to nix/hosts/carters-macbook-pro, which
# turns them off. Skip it here so zsh/try starts as fast as the installed shell.
export NOSYSZSHRC=1
