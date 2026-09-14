{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  agent-browser = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  bambu-studio = self.packages.${pkgs.stdenv.hostPlatform.system}.bambu-studio;
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

  # Pinned to 0.1.9: newer kubelogin does not persist the Ethos device-code
  # token, so every kubectl call re-prompts a browser login. 0.1.9 caches it.
  # https://wiki.corp.adobe.com/spaces/ethos/pages/1710311412 (section 2.1.1)
  kubelogin = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kubelogin";
    version = "0.1.9";
    src = pkgs.fetchurl {
      url = "https://github.com/Azure/kubelogin/releases/download/v${version}/kubelogin-darwin-arm64.zip";
      hash = "sha256-lNmnm72mLKZWgiIN4mI6r/XM7MCe1rkT6E4Dd/7hBZw=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/darwin_arm64/kubelogin $out/bin/kubelogin
      runHook postInstall
    '';
  };

  commonPackages = with pkgs; [
    age
    agent-browser
    aria2
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
    kubectl
    kubelogin
    fff-mcp
    openspec
    vault
  ];

  nixosPackages = with pkgs; [
    bambu-studio
    bibata-cursors
    discord
    dolphin-emu
    google-chrome
    heroic
    lmstudio
    papirus-icon-theme
    playerctl
    protonplus
    sgdboop
    stable-diffusion-cpp-vulkan
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
