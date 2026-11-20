{ pkgs, ... }:

{
  environment.interactiveShellInit = ''
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';

  environment.systemPackages = with pkgs; [
    agent-browser
    ardia
    aria2
    astro-language-server
    ast-grep
    bash-language-server
    bc
    bun
    codex
    dnsutils
    docker-language-server
    dust
    fastfetch
    ffmpeg
    file
    fish-lsp
    git-crypt
    gnupg
    go
    herdr
    home-assistant-cli
    hunk
    hyperfine
    klad
    lsof
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
    unzip
    vscode-css-languageserver
    vscode-json-languageserver
    uv
    yaml-language-server
    zen-browser
  ];
}
