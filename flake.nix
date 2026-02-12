{
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    elephant.url = "github:abenz1267/elephant";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, disko, walker, ... }:
  let
    darwinConfiguration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages = with pkgs; [
        btop
        curl
        git
        gnupg
        ouch
        rsync
        tinty
        wget
        markdown-oxide
        nil
        nodePackages_latest.vscode-json-languageserver
        yaml-language-server
      ];

      nix.settings.experimental-features = "nix-command flakes";
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 6;
      ids.gids.nixbld = 30000;
      nixpkgs.hostPlatform = "aarch64-darwin";

      programs.zsh.enable = true;
      programs.fish.enable = true;

      nix.gc.automatic = true;
      nix.gc.options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

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

      fonts.packages = [
        pkgs.nerd-fonts.noto
        pkgs.iosevka-bin
      ];
    };
  in
  {
    nixosConfigurations.scylla = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        disko.nixosModules.disko
        ./nixos/disk-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.carter = ./nixos/home-carter-scylla.nix;
        }
        walker.nixosModules.default
        {
          programs.walker.enable = true;
        }
      ];
    };

    darwinConfigurations."Carters-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [ darwinConfiguration ];
    };

    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
  };
}
