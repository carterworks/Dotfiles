{ config, pkgs, ... }:

let 
  lsps = [
    pkgs.markdown-oxide
    pkgs.nil
    pkgs.nodePackages_latest.vscode-json-languageserver
    pkgs.taplo
    pkgs.yaml-language-server
  ];
in {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs;
    [
      any-nix-shell
      bat
      bottom
      bun
      colima
      delta
      docker
      eza
      fd
      ffmpeg
      fnm
      fzf
      git
      helix
      jq
      (python3.withPackages (p: [ p.llm p.llm-ollama p.llm-cmd ]))
      ripgrep
      starship
      yazi
      uv
      zoxide
    ] ++ lsps;

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nixVersions.stable;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina
  programs.fish = {
    enable = true;
    promptInit = "";
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Keep things clean
  nix.gc.automatic = true;
  nix.gc.options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

  # Extra configs–https://daiderd.com/nix-darwin/manual/index.html#sec-options
  environment.shells = [ pkgs.fish ];
  fonts.packages = [
    pkgs.nerd-fonts.noto
    pkgs.iosevka
  ];
  system.defaults = {
    dock = {
      autohide = false;
      mineffect = "scale";
      minimize-to-application = true;
      orientation = "left";
      show-recents = true;
      show-process-indicators = true;
      tilesize = 40;
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
