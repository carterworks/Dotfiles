{ pkgs, self, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.vorssaint
  ];

  system.stateVersion = 6;

  ids.gids.nixbld = 30000;
}
