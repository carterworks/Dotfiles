{
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://vicinae.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
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
    vicinae.url = "github:vicinaehq/vicinae";
    numtide-llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.systems.follows = "systems";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
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
            shellcheck --severity=warning ${source}/check ${source}/install ${source}/update
            touch "$out"
          '';
        }
      );
      scylla = mkSystem "scylla" {
        system = "x86_64-linux";
        profile = "carter";
        extraModules = [ inputs.disko.nixosModules.disko ];
      };
      prostagma = mkSystem "prostagma" {
        system = "x86_64-linux";
        profile = "root";
        systemUsername = "root";
        gui = false;
        extraModules = [ inputs.copyparty.nixosModules.default ];
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

      nixosConfigurations = { inherit prostagma scylla; };
      darwinConfigurations = {
        "Carters-MacBook-Pro" = carters-macbook-pro;
        "Carters-MacBook-Pro-2" = carters-macbook-pro;
      };

      checks.aarch64-darwin = repositoryChecks.aarch64-darwin // {
        inherit (packageSets.aarch64-darwin)
          dotbot
          nub
          fff-mcp
          opencode2
          ;
        carters-macbook-pro = carters-macbook-pro.system;
      };
      checks.x86_64-linux = repositoryChecks.x86_64-linux // {
        inherit (packageSets.x86_64-linux)
          bambu-studio
          dotbot
          nub
          obsidian-headless
          fff-mcp
          opencode2
          ;
        prostagma = prostagma.config.system.build.toplevel;
        scylla = scylla.config.system.build.toplevel;
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
