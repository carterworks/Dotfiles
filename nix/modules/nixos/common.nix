{ inputs, ... }:

{
  imports = [
    ../common.nix
    ./binary-cache.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };
}
