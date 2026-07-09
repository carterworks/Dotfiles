{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;

  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 7d";
}
