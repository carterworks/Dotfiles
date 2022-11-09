{ config, pkgs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [ 
      pkgs.any-nix-shell
      pkgs.bat
      pkgs.delta
      pkgs.fd
      pkgs.ffmpeg
      pkgs.fzf
      pkgs.git
      pkgs.helix
      pkgs.jq
      pkgs.lsd
      pkgs.micro
      pkgs.neofetch
      pkgs.neovim
      pkgs.ripgrep
      pkgs.starship
      pkgs.zoxide
    ];

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina
  programs.fish = {
    enable = true;
    promptInit = "";
  };
  programs.tmux = {
    enable = true;
    enableFzf = true;
    enableMouse = true;
    enableSensible = true;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Keep things clean
  nix.gc.automatic = true;
  nix.gc.options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

  # Extra configs–https://daiderd.com/nix-darwin/manual/index.html#sec-options
  environment.shells = [ pkgs.fish ];
  fonts.fonts = [ pkgs.nerdfonts ];
  system.defaults = {
    dock = {
      autohide = true;
      mineffect = "scale";
      minimize-to-application = true;
      orientation = "left";
      show-recents = true;
      show-process-indicators = true;
      tilesize = 50;
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
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      AppleShowScrollBars = "Always";
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.swipescrolldirection" = false;
    };
    trackpad = {
      Clicking = true;
      TrackpadRightClick = false;
    };
  };
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };
}
