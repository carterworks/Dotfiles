{
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems = {
      url = "path:./nix/systems";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    delta = {
      url = "github:zed-industries/delta-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    numtide-llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.systems.follows = "systems";
    };
    # Pinned to the tag that matches the prebuilt Linux release in
    # nix/packages/hex.nix; ./update bumps both together.
    hex = {
      url = "github:anomalyco/hex/v3.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Locked to the rev the standalone eltoro repo ran; see TODO.md before
    # letting ./update bump it.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      mkSystem = import ./nix/lib/mksystem.nix {
        inherit inputs nixpkgs self;
      };
      mkPackages = import ./nix/packages { inherit inputs nixpkgs; };
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      source = self.outPath;
      nixFiles = nixpkgs.lib.filter (nixpkgs.lib.hasSuffix ".nix") (
        nixpkgs.lib.filesystem.listFilesRecursive source
      );
      packageSets = nixpkgs.lib.genAttrs systems mkPackages;
      repositoryChecks = nixpkgs.lib.genAttrs systems (
        system:
        let
          browserSkill = packageSets.${system}.agent-browser-skill;
          herdrSkill = packageSets.${system}.herdr-skill;
          hunkSkill = packageSets.${system}.hunk-skill;
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          dotbot-config = pkgs.runCommandLocal "dotbot-config-check" { } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            ${pkgs.dotbot}/bin/dotbot \
              --exit-on-failure \
              --dry-run \
              --base-directory ${source} \
              --config-file ${source}/install.conf.yaml
            touch "$out"
          '';
          agent-browser-skill =
            pkgs.runCommandLocal "agent-browser-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; }
              ''
                diff -u ${source}/agents/skills/generated/agent-browser/SKILL.md ${browserSkill}
                touch "$out"
              '';
          hunk-skill = pkgs.runCommandLocal "hunk-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
            diff -u ${source}/agents/skills/generated/hunk-review/SKILL.md ${hunkSkill}
            touch "$out"
          '';
          herdr-skill =
            pkgs.runCommandLocal "herdr-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; }
              ''
                diff -u ${source}/agents/skills/generated/herdr/SKILL.md ${herdrSkill}
                touch "$out"
              '';
          nixfmt = pkgs.runCommandLocal "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            nixfmt --check ${nixpkgs.lib.escapeShellArgs nixFiles}
            touch "$out"
          '';
          shellcheck = pkgs.runCommandLocal "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck --severity=warning ${source}/check ${source}/install ${source}/install-eltoro ${source}/update ${source}/tests/hermes-settings-writable
            touch "$out"
          '';
          install =
            pkgs.runCommandLocal "install-check"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.python3
                ];
              }
              ''
                python3 ${source}/test-install.py
                touch "$out"
              '';
          install-eltoro =
            pkgs.runCommandLocal "install-eltoro-check"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.python3
                ];
              }
              ''
                python3 ${source}/test-install-eltoro.py
                touch "$out"
              '';
          update =
            pkgs.runCommandLocal "update-check"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.jq
                  pkgs.python3
                ];
              }
              ''
                python3 ${source}/test-update.py
                touch "$out"
              '';
          obsidian-sync-module =
            assert import ./nix/tests/obsidian-sync.nix { inherit (nixpkgs) lib; };
            pkgs.runCommandLocal "obsidian-sync-module-check" { } ''
              touch "$out"
            '';
        }
      );
      scylla = mkSystem "scylla" {
        system = "x86_64-linux";
        profile = "carter";
        extraModules = [
          inputs.disko.nixosModules.disko
        ];
      };
      prostagma = mkSystem "prostagma" {
        system = "x86_64-linux";
        profile = "root";
        systemUsername = "root";
        gui = false;
        extraModules = [
          inputs.copyparty.nixosModules.default
        ];
      };
      eltoro = mkSystem "eltoro" {
        system = "x86_64-linux";
        profile = "root";
        gui = false;
      };
      carters-macbook-pro = mkSystem "carters-macbook-pro" {
        system = "aarch64-darwin";
        profile = "carter";
        systemUsername = "cmcbride";
        darwin = true;
        extraModules = [ inputs.determinate.darwinModules.default ];
      };
    in
    {
      packages = packageSets;

      nixosConfigurations = { inherit eltoro prostagma scylla; };
      darwinConfigurations = {
        "Carters-MacBook-Pro" = carters-macbook-pro;
        "Carters-MacBook-Pro-2" = carters-macbook-pro;
      };

      checks.aarch64-darwin = repositoryChecks.aarch64-darwin // {
        inherit (packageSets.aarch64-darwin)
          dotbot
          hex
          rex-client
          nub
          ;
        carters-macbook-pro = carters-macbook-pro.system;
      };
      checks.x86_64-linux = repositoryChecks.x86_64-linux // {
        desktop-theme =
          let
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            home = scylla.config.home-manager.users.carter;
            theme = import (./nix/users/carter/themes + "/${home.dotfiles.desktopTheme.name}.nix");
            obsidian = home.xdg.configFile."desktop-theme/obsidian".source;
            manifest = pkgs.writeText "desktop-theme-check.json" (
              builtins.toJSON {
                inherit (theme) appearance apps colors;
                palettes = map (file: (import (./nix/users/carter/themes + "/${file}")).colors) (
                  builtins.filter (nixpkgs.lib.hasSuffix ".nix") (
                    builtins.attrNames (builtins.readDir ./nix/users/carter/themes)
                  )
                );
                fzfOptions = home.home.sessionVariables.FZF_DEFAULT_OPTS;
                files = {
                  opencode = home.xdg.configFile."opencode/cli.json".source;
                  opencodeBase = ./opencode/cli.json;
                  herdr = home.xdg.configFile."herdr/config.toml".source;
                  herdrBase = ./herdr/config.toml;
                  vicinae = home.xdg.configFile."vicinae/desktop-theme.json".source;
                  vicinaeTheme = home.xdg.dataFile."vicinae/themes/${home.dotfiles.desktopTheme.name}.toml".source;
                  helix = home.xdg.configFile."helix/config.toml".source;
                  helixBuiltin = "${pkgs.helix-unwrapped.src}/runtime/themes/${theme.apps.helix}.toml";
                  zellijBuiltin = "${pkgs.zellij-unwrapped.src}/zellij-utils/assets/themes/${theme.apps.zellij}.kdl";
                  zed = home.xdg.configFile."zed/themes/desktop-theme.json".source;
                  obsidianSettings = home.xdg.configFile."desktop-theme/obsidian.json".source;
                  obsidianManifest = "${obsidian}/manifest.json";
                  obsidianCss = "${obsidian}/theme.css";
                  kde = home.xdg.dataFile."color-schemes/${home.dotfiles.desktopTheme.name}.colors".source;
                  gtk3 = home.xdg.configFile."gtk-3.0/colors.css".source;
                  gtk4 = home.xdg.configFile."gtk-4.0/colors.css".source;
                  gtk4Css = home.xdg.configFile."gtk-4.0/gtk.css".source;
                  btop = home.xdg.configFile."btop/btop.conf".source;
                  btopTheme =
                    if theme.apps ? btopTheme then
                      home.xdg.configFile."btop/themes/${theme.apps.btop}.theme".source
                    else
                      null;
                  fish = home.xdg.configFile."fish/config.fish".source;
                  zedSettings = home.xdg.configFile."zed/settings.json".source;
                  zellij = home.xdg.configFile."zellij/config.kdl".source;
                  heroic = home.xdg.configFile."desktop-theme/heroic/${home.dotfiles.desktopTheme.name}.css".source;
                  telegram =
                    home.xdg.configFile."desktop-theme/telegram/${home.dotfiles.desktopTheme.name}.tdesktop-theme".source;
                };
              }
            );
          in
          pkgs.runCommandLocal "desktop-theme-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            python3 ${source}/nix/users/carter/test-obsidian-theme.py
            python3 ${source}/nix/users/carter/test-kde-theme.py
            python3 ${source}/nix/users/carter/test-live-desktop-theme.py
            python3 ${source}/nix/users/carter/test-vicinae-onboarding.py
            python3 ${source}/nix/users/carter/test-desktop-theme.py ${manifest}
            touch "$out"
          '';
        sunshine-display =
          let
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
          in
          pkgs.runCommandLocal "sunshine-display-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.jq
                pkgs.python3
                pkgs.util-linux
              ];
            }
            ''
              python3 ${source}/nix/users/carter/test-sunshine-display.py
              touch "$out"
            '';
        inherit (packageSets.x86_64-linux)
          bambu-studio
          dotbot
          nub
          ;
        binary-cache = import ./nix/tests/binary-cache.nix { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
        eltoro = eltoro.config.system.build.toplevel;
        eltoro-egress = nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest ./nix/tests/eltoro-egress.nix;
        hermes-settings-repair = import ./nix/tests/hermes-settings-repair.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          repair = eltoro.config.systemd.services.hermes-settings-repair.serviceConfig.ExecStart;
          activation = eltoro.config.system.activationScripts.hermes-settings.text;
        };
        prostagma = prostagma.config.system.build.toplevel;
        scylla = scylla.config.system.build.toplevel;
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
