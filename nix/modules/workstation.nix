{ pkgs, ... }:

{
  environment.interactiveShellInit = ''
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';

  environment.systemPackages = with pkgs; [
    agent-browser
    aria2
    astro-language-server
    ast-grep
    bash-language-server
    bun
    codex
    docker-language-server
    dust
    fastfetch
    ffmpeg
    fish-lsp
    git-crypt
    gnupg
    go
    herdr
    home-assistant-cli
    hunk
    hyperfine
    markdown-oxide
    nodejs_24
    neovim
    nixd
    nub
    obsidian
    opencode2
    opencode2-desktop
    ouch
    pnpm
    rclone
    rsync
    ruff
    spotify
    sshpass
    superhtml
    t3code-cli
    t3code-nightly
    taplo
    tmux
    typescript-language-server
    vscode-css-languageserver
    vscode-json-languageserver
    uv
    yaml-language-server
    zen-browser
  ];
}
