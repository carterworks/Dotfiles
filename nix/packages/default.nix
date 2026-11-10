{
  inputs,
  nixpkgs,
}:

system:

let
  overlay = import ./overlay.nix { inherit inputs; };
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ overlay ];
  };
in
nixpkgs.lib.getAttrs (builtins.attrNames (overlay pkgs pkgs)) pkgs
