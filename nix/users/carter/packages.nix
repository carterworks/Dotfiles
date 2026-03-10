{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  bambu-studio-appimage = import ./bambu-studio-appimage.nix { inherit pkgs lib; };

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
    fish-lsp
    gh

    gum

    hyperfine
    jq

    markdown-oxide
    nodejs
    ouch
    neovim
    nixd
    pnpm
    python3
    rclone
    ripgrep
    rsync
    ruff
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
    claude-code-bin
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

      nautilus
      obsidian
      opencode
      opencode-desktop
      papirus-icon-theme
      playerctl
      spotify
      sshpass
      slurp
      systemd-lsp
      telegram-desktop
      trayscale
      wallust
      wlogout
      wtype
      xan
      xdotool

    ]
    ++ [ inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default ];
in
{
  environment.systemPackages =
    commonPackages
    ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
    ++ lib.optionals pkgs.stdenv.isLinux nixosPackages;

  environment.variables = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };
}
