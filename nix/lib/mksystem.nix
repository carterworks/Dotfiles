{
  inputs,
  nixpkgs,
  self,
}:

name:
{
  system,
  user,
  darwin ? false,
  extraModules ? [ ],
}:

let
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  userConfig = ../users/${user}/${if darwin then "darwin" else "nixos"}.nix;
in
systemFunc {
  inherit system;

  modules = [
    {
      _module.args = {
        inherit inputs self user;
        currentSystem = system;
        currentSystemName = name;
      };
    }
    ../modules/nix.nix
    ../modules/fonts.nix
    ../machines/${name}.nix
    ../users/${user}/packages.nix
    userConfig
  ]
  ++ extraModules;
}
