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
    atuin
    bash-language-server
    bat
    btop
    bun
    curl
    delta
    docker-language-server
    dust
    eza
    fastfetch
    fd
    ffmpeg-full
    fish
    fish-lsp
    fzf
    gh
    git
    gum
    helix
    hyperfine
    jq
    jujutsu
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
    starship
    superhtml
    taplo
    typescript-language-server
    vscode-css-languageserver
    vscode-json-languageserver
    uv
    wget
    yazi
    yaml-language-server
    zoxide
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
      ghostty
      google-chrome
      grim
      heroic
      hyprpaper
      hyprpicker
      hyprpolkitagent
      hyprshutdown
      hyprls
      mako
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
