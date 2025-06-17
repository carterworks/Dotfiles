{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs; [
        any-nix-shell
        bat
        bottom
        bun
        delta
        eza
        fd
        ffmpeg
        fnm
        fzf
        git
        gh
        helix
        jq
        (python3.withPackages (p: [ p.llm p.llm-ollama p.llm-cmd ]))
        rclone
        rsync
        ripgrep
        starship
        yazi
        uv
        zoxide
        # lsps
        markdown-oxide
        nil
        nodePackages_latest.vscode-json-languageserver
        taplo
        yaml-language-server
      ];

      homebrew = {
        enable = true;

        brews = [
          "dependency-check"
        ];

        casks = [
          "nikitabobko/tap/aerospace"
        ];
      };

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;
      ids.gids.nixbld = 30000;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Enable alternative shell support in nix-darwin.
      # Use NixOS zsh
      programs.zsh.enable = true;
      # Use Fish as the default
      programs.fish.enable = true;
      environment.shells = [ pkgs.fish ];

      # Automatically clean the cache
      nix.gc.automatic = true;
      nix.gc.options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

      # MacOS settings
      system.primaryUser = "cmcbride";
      # sudo with touch id
      security.pam.services.sudo_local.touchIdAuth = true;
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

      # fonts
      fonts.packages = [
        pkgs.nerd-fonts.noto
        pkgs.iosevka
      ];
};
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."Carters-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}
