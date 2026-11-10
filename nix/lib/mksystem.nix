{
  inputs,
  nixpkgs,
  self,
}:

name:
{
  system,
  profile,
  systemUsername ? profile,
  darwin ? false,
  gui ? true,
  extraModules ? [ ],
}:

let
  lib = nixpkgs.lib;
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  homeManagerModule =
    if darwin then
      inputs.home-manager.darwinModules.home-manager
    else
      inputs.home-manager.nixosModules.home-manager;
  userConfig = ../users/${profile}/${if darwin then "darwin" else "nixos"}.nix;
  homeConfig = ../users/${profile}/home-manager.nix;
in
systemFunc {
  inherit system;
  specialArgs = { inherit inputs self systemUsername; };

  modules = [
    ../modules/nix.nix
  ]
  ++ lib.optional gui ../modules/fonts.nix
  ++ lib.optional (!darwin) ../modules/binary-cache.nix
  ++ [
    homeManagerModule
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = false;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {
          inherit inputs self;
        };
        users.${systemUsername} = homeConfig;
      };
    }
    ../hosts/${name}
    ../users/${profile}/packages.nix
    userConfig
  ]
  ++ extraModules;
}
