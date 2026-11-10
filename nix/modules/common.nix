{ inputs, ... }:

let
  inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
in
{
  nixpkgs.overlays = [ (import ../packages/overlay.nix { inherit inputs; }) ];

  nix.settings = {
    substituters = [ "https://cache.nixos.org" ] ++ extra-substituters;
    trusted-public-keys = extra-trusted-public-keys;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
  };
}
