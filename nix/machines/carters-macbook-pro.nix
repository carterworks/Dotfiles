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
    })
  ];

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;
}
