{
  inputs,
  pkgs,
  ...
}:

let
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
in
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
    gum
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
    # Nightly desktop app and CLI. Upstream publishes self-contained builds, so
    # these are fetch-and-wrap instead of llm-agents source builds.
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
