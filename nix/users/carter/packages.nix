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
  codex = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  delta = self.packages.${pkgs.stdenv.hostPlatform.system}.delta;
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
  github-desktop = self.packages.${pkgs.stdenv.hostPlatform.system}.github-desktop;
  herdr = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  openspec = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openspec;
  nub = self.packages.${pkgs.stdenv.hostPlatform.system}.nub;
  opencode2 = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  opencode2-desktop =
    inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2-desktop;
  # Nightly desktop app and CLI. Upstream publishes self-contained builds, so
  # these are fetch-and-wrap instead of llm-agents source builds.
  t3code-cli = self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-cli;
  t3code-desktop = self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-nightly;
  # nixpkgs still ships sd.cpp 656a135 (2026-09-18), which predates Qwen Image
  # 2.1 support (137f740) and the Qwen Image 2.1 Turbo sigma preset. Pin the
  # upstream master until the nixpkgs package catches up.
  stableDiffusionCppPin = {
    version = "master-1d0a58a";
    src = pkgs.fetchFromGitHub {
      owner = "leejet";
      repo = "stable-diffusion.cpp";
      rev = "1d0a58a35050d285b1d6fb1bc68a92924d35825e";
      hash = "sha256-7LO5nROQhHkkv2iJsYd9ZAhShV0ZOzN94Y0+xTfFwxE=";
      fetchSubmodules = true;
    };
  };
  # The base package enables Metal by default on aarch64-darwin; Vulkan is the
  # Linux equivalent.
  stableDiffusionCppMetal = pkgs.stable-diffusion-cpp.overrideAttrs stableDiffusionCppPin;
  stableDiffusionCppVulkan = pkgs.stable-diffusion-cpp-vulkan.overrideAttrs stableDiffusionCppPin;
  # Use the host package set for compatibility with its GPU drivers and libc.
  vicinae = pkgs.vicinae;
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;

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
    t3code-cli
    t3code-desktop
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

  darwinPackages = with pkgs; [
    awscli2
    github-copilot-cli
    github-desktop
    kubectl
    kubelogin
    openspec
    stableDiffusionCppMetal
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
    stableDiffusionCppVulkan
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
