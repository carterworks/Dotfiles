{
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://vicinae.cachix.org"
      "https://nix-community.cachix.org"
      "https://nix-amd-ai.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
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
    numtide-llm-agents.url = "github:numtide/llm-agents.nix";
    openspec.url = "github:Fission-AI/OpenSpec";
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fff-mcp-aarch64-darwin = {
      url = "file+https://github.com/dmtrKovalenko/fff.nvim/releases/latest/download/fff-mcp-aarch64-apple-darwin";
      flake = false;
    };
    fff-mcp-x86_64-linux = {
      url = "file+https://github.com/dmtrKovalenko/fff.nvim/releases/latest/download/fff-mcp-x86_64-unknown-linux-gnu";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      mkSystem = import ./nix/lib/mksystem.nix {
        inherit inputs nixpkgs self;
      };
      mkFffMcp = import ./nix/packages/fff-mcp.nix;
      mkNub = import ./nix/packages/nub.nix;
    in
    {
      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          fffMcpAssets = {
            aarch64-darwin = inputs.fff-mcp-aarch64-darwin;
            x86_64-linux = inputs.fff-mcp-x86_64-linux;
          };
        in
        {
          dotbot = pkgs.dotbot;
          fff-mcp = mkFffMcp {
            inherit pkgs fffMcpAssets;
            lib = nixpkgs.lib;
          };
          nub = mkNub {
            inherit pkgs;
            lib = nixpkgs.lib;
          };
        }
      );

      nixosConfigurations.scylla = mkSystem "scylla" {
        system = "x86_64-linux";
        profile = "carter";
        extraModules = [
          inputs.disko.nixosModules.disko
          inputs.nix-amd-ai.nixosModules.default
        ];
      };

      nixosConfigurations.prostagma = mkSystem "prostagma" {
        system = "x86_64-linux";
        profile = "root";
        systemUsername = "root";
        gui = false;
        extraModules = [ inputs.copyparty.nixosModules.default ];
      };

      darwinConfigurations."Carters-MacBook-Pro" = mkSystem "carters-macbook-pro" {
        system = "aarch64-darwin";
        profile = "carter";
        systemUsername = "cmcbride";
        darwin = true;
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
