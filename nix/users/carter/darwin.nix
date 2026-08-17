{
  self,
  systemUsername,
  pkgs,
  ...
}:

let
  home = "/Users/${systemUsername}";
  litellmConfigDir = "${home}/.config/litellm";
in
{
  determinateNix = {
    enable = true;
    customSettings = {
      trusted-users = [
        "root"
        "@admin"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://cache.numtide.com"
        "https://vicinae.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    determinateNixd.garbageCollector.strategy = "automatic";
  };

  users.users.${systemUsername} = {
    name = systemUsername;
    home = "/Users/${systemUsername}";
  };

  launchd.user.agents.litellm = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        ''
          export HOME=${home}
          export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"
          set -e
          RENDERED=$(${pkgs.coreutils}/bin/mktemp --tmpdir litellm-config.XXXXXX)
          trap 'rm -f "$RENDERED"' EXIT
          ${pkgs.fnox}/bin/fnox exec -- ${pkgs.gettext}/bin/envsubst < ${litellmConfigDir}/config.yaml > "$RENDERED"
          chmod 600 "$RENDERED"
          exec ${pkgs.litellm}/bin/litellm --config "$RENDERED" --host 127.0.0.1 --port 4000
        ''
      ];
      EnvironmentVariables = {
        LITELLM_MCP_STDIO_EXTRA_COMMANDS = "fj-mcp,scout";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/litellm.log";
      StandardErrorPath = "${home}/Library/Logs/litellm.error.log";
    };
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [ ];
    brews = [ ];
    casks = [
      "bitwarden"
      "lunar"
      "podman-desktop"
      "space-rabbit"
      "zed"
    ];
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;

  home-manager.users.${systemUsername}.home.sessionVariables.CODEHOME = "$HOME/homebase/code";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.primaryUser = systemUsername;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
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
