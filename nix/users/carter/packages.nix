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
  handy = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.handy;
  herdr = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  hunk = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hunk;
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  openspec = inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default;
  nub = self.packages.${pkgs.stdenv.hostPlatform.system}.nub;
  pi-coding-agent = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
  vicinae = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;

  commonPackages = with pkgs; [
    age
    agent-browser
    astro-language-server
    ast-grep
    aube
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
    fff-mcp
    fish-lsp
    fnox
    git-crypt
    gnupg
    go
    gum
    handy
    herdr
    home-assistant-cli
    hunk
    hyperfine
    jq
    markdown-oxide
    nodejs_latest
    neovim
    nixd
    nub
    obsidian
    opencode
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
    openspec
    tinty
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
    spotify
    sshpass
    systemd-lsp
    telegram-desktop
    trayscale
    vicinae
    wallust
    xan
  ];
in
{
  environment.systemPackages =
    commonPackages
    ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.isLinux nixosPackages;
}
