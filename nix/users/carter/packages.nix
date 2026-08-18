{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  agent-browser = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  bambu-studio-appimage = import ./bambu-studio-appimage.nix { inherit pkgs lib; };
  claude = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  codex = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
  handy = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.handy;
  herdr = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  openspec = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openspec;
  nub = self.packages.${pkgs.stdenv.hostPlatform.system}.nub;
  opencode2 = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  pi-coding-agent = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  vicinae = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;

  commonPackages = with pkgs; [
    age
    agent-browser
    astro-language-server
    ast-grep
    bash-language-server
    brave
    btop
    bun
    codex
    curl
    docker-language-server
    dust
    fastfetch
    fd
    ffmpeg
    fish-lsp
    fnox
    git-crypt
    gnupg
    go
    gum
    handy
    herdr
    home-assistant-cli
    hyperfine
    jq
    markdown-oxide
    nodejs_latest
    neovim
    nixd
    nub
    obsidian
    inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    opencode2
    ouch
    pi-coding-agent
    pnpm
    rclone
    ripgrep
    rsync
    ruff
    spotify
    sshpass
    superhtml
    taplo
    tmux
    typescript-language-server
    vscode-css-languageserver
    vscode-json-languageserver
    uv
    wget
    yaml-language-server
  ];

  darwinPackages = with pkgs; [
    awscli2
    claude
    fff-mcp
    litellm
    openspec
    tinty
    vault
  ];

  nixosPackages = with pkgs; [
    bambu-studio-appimage
    bibata-cursors
    discord
    dolphin-emu
    google-chrome
    heroic
    libreoffice-fresh
    lmstudio
    papirus-icon-theme
    playerctl
    protonplus
    sgdboop
    systemd-lsp
    telegram-desktop
    trayscale
    vicinae
    wallust
    wl-clipboard
    xan
  ];
in
{
  environment.systemPackages =
    commonPackages
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux nixosPackages;
}
