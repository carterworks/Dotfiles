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
  bambu-studio-appimage = import ./bambu-studio-appimage.nix { inherit pkgs lib; };
  opencode = inputs.numtime-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  rtk = inputs.numtime-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk;
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;

  commonPackages = with pkgs; [
    astro-language-server
    bash-language-server
    btop
    bun
    curl
    docker-language-server
    dust
    fastfetch
    fd
    ffmpeg-full
    fff-mcp
    fish-lsp

    gum

    hyperfine
    jq

    markdown-oxide
    nodejs
    ouch
    neovim
    nixd
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
      brave
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
      obsidian
      papirus-icon-theme
      playerctl
      protonplus
      spotify
      sshpass
      slurp
      systemd-lsp
      telegram-desktop
      trayscale
      wallust
      wl-clipboard
      wlogout
      wtype
      xan
      xdotool

    ]
    ++ [ opencode ]
    ++ [ inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default ];
in
{
  environment.systemPackages =
    commonPackages
    ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.isLinux nixosPackages;

}
