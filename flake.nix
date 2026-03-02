{
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
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
    hyprland.url = "github:hyprwm/Hyprland";
    vicinae.url = "github:vicinaehq/vicinae";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      disko,
      vicinae,
      ...
    }:
    let
      darwinPackages =
        pkgs: with pkgs; [
          atuin
          bat
          btop
          pkgs."bitwarden-cli"
          bun
          curl
          delta
          dust
          eza
          fd
          fzf
          gh
          git
          gnupg
          gum
          helix
          hyperfine
          jq
          jujutsu
          markdown-oxide
          neovim
          nil
          nodePackages_latest.vscode-json-languageserver
          nodejs
          pnpm
          ouch
          python3
          rclone
          ripgrep
          rsync
          starship
          taplo
          terminal-notifier
          typescript-language-server
          tinty
          uv
          wget
          vscode-css-languageserver
          yaml-language-server
          yazi
          zoxide
        ];

      darwinConfiguration =
        { pkgs, ... }:
        {
          nixpkgs.config.allowUnfree = true;
          environment.systemPackages = darwinPackages pkgs;
          homebrew.enable = true;
          homebrew.taps = [ "PeonPing/tap" ];
          homebrew.brews = [
            "peon-ping"
          ];

          environment.variables = {
            UV_PYTHON = "${pkgs.python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
          };

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

      darwinPkgs = nixpkgs.legacyPackages.aarch64-darwin;

      mkDarwinApp =
        name: text:
        let
          app = darwinPkgs.writeShellScriptBin name text;
        in
        {
          type = "app";
          program = "${app}/bin/${name}";
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
        ];
      };

      darwinConfigurations."Carters-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [ darwinConfiguration ];
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
