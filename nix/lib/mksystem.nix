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
  extraModules ? [ ],
}:

let
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  pkgsMaster = inputs.nixpkgs-master.legacyPackages.${system};
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

  modules = [
    {
      _module.args = {
        inherit
          inputs
          pkgsMaster
          self
          profile
          systemUsername
          ;
        currentSystem = system;
        currentSystemName = name;
      };
    }
    ../modules/nix.nix
    ../modules/fonts.nix
    homeManagerModule
    {
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
            ;
          currentSystem = system;
          currentSystemName = name;
        };
        users.${systemUsername} = homeConfig;
      };
    }
    ../machines/${name}.nix
    ../users/${profile}/packages.nix
    userConfig
  ]
  ++ extraModules;
}
