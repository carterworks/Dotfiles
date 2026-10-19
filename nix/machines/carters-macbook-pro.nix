{ inputs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # TODO: remove once NixOS/nixpkgs#560971 is fixed upstream — the dmg source
  # contains multiple top-level directories, so stdenv's unpackPhase fails to
  # guess sourceRoot.
  nixpkgs.overlays = [
    (_final: prev: {
      brave = prev.brave.overrideAttrs (_old: {
        sourceRoot = "Brave Browser.app";
      });

      # Temporary: use the cached build with NixOS/nixpkgs#574509, without
      # overriding its attributes (which would force another source build).
      # To validate removal, follow TODO.md to update the main nixpkgs input,
      # then remove this assignment and the nixpkgs-atuin input/lock entry.
      # From the repository root, require a cached build (no local builds):
      # nix build --no-link --max-jobs 0 .#darwinConfigurations.Carters-MacBook-Pro.pkgs.atuin
      # Then run ./install before completing the TODO.
      atuin = inputs.nixpkgs-atuin.legacyPackages.aarch64-darwin.atuin;
    })
  ];

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;
}
