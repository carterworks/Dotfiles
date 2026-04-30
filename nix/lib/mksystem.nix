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
  homeManager ? true,
  extraModules ? [ ],
}:

let
  lib = nixpkgs.lib;
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  pkgsMaster = (inputs.nixpkgs-master or inputs.nixpkgs).legacyPackages.${system};
  homeManagerModule =
    lib.optional homeManager (
      if darwin then
        inputs.home-manager.darwinModules.home-manager
      else
        inputs.home-manager.nixosModules.home-manager
    );
  userConfig = ../users/${profile}/${if darwin then "darwin" else "nixos"}.nix;
  homeConfig = ../users/${profile}/home-manager.nix;
in
systemFunc {
  inherit system;

  modules = [
    {
      _module.args = {
        inherit
          inputs
          pkgsMaster
          self
          profile
          systemUsername
          gui
          homeManager
          ;
        currentSystem = system;
        currentSystemName = name;
      };
    }
    ../modules/nix.nix
  ]
  ++ lib.optional gui ../modules/fonts.nix
  ++ homeManagerModule
  ++ lib.optional homeManager {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = false;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {
          inherit
            inputs
            pkgsMaster
            self
            profile
            systemUsername
            gui
            homeManager
            ;
          currentSystem = system;
          currentSystemName = name;
        };
        users.${systemUsername} = homeConfig;
      };
    }
  ++ [
    ../machines/${name}.nix
    ../users/${profile}/packages.nix
    userConfig
  ]
  ++ extraModules;
}
