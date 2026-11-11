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
    numtide-llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.systems.follows = "systems";
    };
    # Pinned to the tag that matches the prebuilt Linux release in
    # nix/packages/hex.nix; ./update bumps both together.
    hex = {
      url = "github:anomalyco/hex/v3.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Held at the rev the standalone eltoro repo ran, so ./update leaves it
    # alone; see TODO.md. Bump it by editing the rev here, then run
    # `nix flake update hermes-agent`.
    hermes-agent.url = "github:NousResearch/hermes-agent/4e865d42d137494d659cbd241f51a7d0fd4fbcba";
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
      systems = import inputs.systems;
      specialArgs = {
        inherit inputs self;
        fleet = import ./nix/lib/fleet.nix;
      };
      nixosSystem =
        host:
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./nix/hosts/${host} ];
        };
      carters-macbook-pro = inputs.nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        modules = [ ./nix/hosts/carters-macbook-pro ];
      };
    in
    {
      packages = nixpkgs.lib.genAttrs systems (import ./nix/packages { inherit inputs nixpkgs; });

      nixosConfigurations = nixpkgs.lib.genAttrs [ "eltoro" "prostagma" "scylla" ] nixosSystem;
      darwinConfigurations = {
        "Carters-MacBook-Pro" = carters-macbook-pro;
        "Carters-MacBook-Pro-2" = carters-macbook-pro;
      };

      checks = import ./nix/checks.nix { inherit self nixpkgs; };

      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
