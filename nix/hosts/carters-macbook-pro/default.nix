{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
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
in
{
  imports = [
    ../../modules/common.nix
    inputs.home-manager.darwinModules.home-manager
    ../../modules/workstation.nix
    inputs.determinate.darwinModules.default
  ];

  home-manager.users.cmcbride = ../../modules/home/workstation.nix;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  fonts.packages = [ pkgs.nerd-fonts.noto ];

  environment.systemPackages = with pkgs; [
    awscli2
    github-copilot-cli
    hex
    kubectl
    kubelogin
    openspec
    python3
    rex-client
    # The base package enables Metal by default on aarch64-darwin.
    stable-diffusion-cpp
    vault-bin
    vorssaint
  ];

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;

  determinateNix = {
    enable = true;
    customSettings = {
      trusted-users = [
        "root"
        "@admin"
      ];
      inherit (config.nix.settings) substituters trusted-public-keys;
    };
    determinateNixd.garbageCollector.strategy = "automatic";
  };

  users.users.cmcbride = {
    name = "cmcbride";
    home = "/Users/cmcbride";
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    brews = [ ];
    casks = [
      "bitwarden"
      "lunar"
      "podman-desktop"
      "zed"
    ];
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.primaryUser = "cmcbride";

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    # Hex runs from the read-only Nix store; ./update bumps it instead.
    CustomUserPreferences."anomaly.hex".DisableUpdates = true;
    CustomUserPreferences."com.superlogical.rex" = {
      "Workspace.terminalFontPointSize" = 14.0;
      "Workspace.terminalStartupCommand" = lib.getExe pkgs.fish;
    };
    dock = {
      autohide = true;
      mineffect = "scale";
      minimize-to-application = true;
      orientation = "left";
      show-recents = true;
      show-process-indicators = true;
      tilesize = 40;
      magnification = true;
      largesize = 44;
    };
    finder = {
      AppleShowAllExtensions = false;
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
    };
    loginwindow = {
      GuestEnabled = false;
      SHOWFULLNAME = true;
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = null;
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      AppleShowScrollBars = "Always";
      NSStatusItemSelectionPadding = 8;
      NSStatusItemSpacing = 8;
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.swipescrolldirection" = false;
    };
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };
}
