{
  fleet,
  inputs,
  pkgs,
  ...
}:

let
  inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
in
{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ../packages/overlay.nix { inherit inputs; }) ];

  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fd
    fff-mcp
    fnox
    jq
    ripgrep
    wakeonlan
    wget
  ];

  nix.settings = {
    substituters = [ "https://cache.nixos.org" ] ++ extra-substituters;
    trusted-public-keys = extra-trusted-public-keys;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit fleet inputs; };
  };
}
