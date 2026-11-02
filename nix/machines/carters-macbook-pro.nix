{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;

  nixpkgs.overlays = [
    # Temporary: atuin's e2e_ai_sessions tests fail while a Pi session runs locally. See TODO.md.
    (final: prev: {
      atuin = prev.atuin.overrideAttrs { doCheck = false; };
    })
  ];
}
