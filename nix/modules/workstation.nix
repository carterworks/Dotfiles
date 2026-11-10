{
  inputs,
  pkgs,
  self,
  ...
}:

let
  # Kept out of the overlay: there it would also replace the nixpkgs delta
  # that programs.delta in Home Manager runs as Git's pager.
  delta = self.packages.${pkgs.stdenv.hostPlatform.system}.delta;
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
in
{
  environment.systemPackages = with pkgs; [
    age
    agent-browser
    aria2
    astro-language-server
    ast-grep
    bash-language-server
    btop
    bun
    codex
    curl
    delta
    docker-language-server
    dust
    fastfetch
    fd
    fff-mcp
    ffmpeg
    fish-lsp
    fnox
    git-crypt
    gnupg
    go
    gum
    herdr
    home-assistant-cli
    hunk
    hyperfine
    jq
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
    ripgrep
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
    wakeonlan
    wget
    yaml-language-server
    zen-browser
  ];
}
