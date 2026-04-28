{
  inputs,
  currentSystemName,
  lib,
  pkgs,
  pkgsMaster,
  self,
  ...
}:

let
  agent-browser = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  bambu-studio-appimage = import ./bambu-studio-appimage.nix { inherit pkgs lib; };
  claude = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
  handy = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.handy;
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  pi-coding-agent = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  rtk = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
  vicinae = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;

  commonPackages = with pkgs; [
    agent-browser
    astro-language-server
    bash-language-server
    brave
    btop
    bun
    claude
    curl
    docker-language-server
    dust
    fastfetch
    fd
    ffmpeg
    fff-mcp
    fish-lsp
    handy
    gum
    hyperfine
    jq
    markdown-oxide
    nodejs
    neovim
    nixd
    obsidian
    opencode
    ouch
    pi-coding-agent
    pnpm
    rclone
    ripgrep
    rsync
    rtk
    ruff
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
    codex
    gnupg
    terminal-notifier
    tinty
  ];

  nixosPackages =
    with pkgs;
    [
      ashell
      bambu-studio-appimage
      bibata-cursors
      discord
      google-chrome
      grim
      heroic
      hyprpicker
      hyprpolkitagent
      hyprshutdown
      hyprls
      libreoffice-fresh
      papirus-icon-theme
      playerctl
      protonplus
      spotify
      sshpass
      slurp
      systemd-lsp
      telegram-desktop
      trayscale
      vicinae
      wallust
      wl-clipboard
      wlogout
      wtype
      xan
      xdotool
    ];
in
{
  environment.systemPackages =
    commonPackages
    ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.isLinux nixosPackages;

}
