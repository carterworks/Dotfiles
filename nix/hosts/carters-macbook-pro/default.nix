{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

{
  home-manager.users.cmcbride = ../../modules/home/workstation.nix;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.vorssaint
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
