{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  commonPackages = with pkgs; [
    atuin
    bitwarden-cli
    bat
    btop
    bun
    curl
    delta
    dust
    eza
    fastfetch
    ffmpeg-full
    fd
    fish
    fzf
    gh
    git
    gum
    helix
    hyperfine
    jq
    jujutsu
    markdown-oxide
    nodePackages_latest.vscode-json-languageserver
    nodejs
    ouch
    neovim
    nil
    pnpm
    python3
    taplo
    rclone
    ripgrep
    rsync
    starship
    typescript-language-server
    vscode-css-languageserver
    uv
    wget
    yazi
    yaml-language-server
    zoxide
  ];

  darwinPackages = with pkgs; [
    gnupg
    terminal-notifier
    tinty
  ];

  nixosPackages =
    with pkgs;
    [
      ashell
      bibata-cursors
      discord
      ghostty
      google-chrome
      grim
      heroic
      hyprpaper
      hyprpicker
      hyprpolkitagent
      hyprshutdown
      mako
      nautilus
      obsidian
      opencode
      papirus-icon-theme
      playerctl
      spotify
      sshpass
      slurp
      telegram-desktop
      trayscale
      wallust
      wl-clipboard
      wlogout
      xan
      zed-editor
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
