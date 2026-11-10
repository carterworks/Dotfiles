{ inputs, ... }:

{
  imports = [
    ../common.nix
    ./binary-cache.nix
    inputs.home-manager.nixosModules.home-manager
  ];
}
