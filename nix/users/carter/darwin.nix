{ self, ... }:

{
  homebrew = {
    enable = true;
    taps = [ "PeonPing/tap" ];
    brews = [ "peon-ping" ];
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.primaryUser = "cmcbride";

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
