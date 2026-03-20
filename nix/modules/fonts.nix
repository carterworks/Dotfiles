{ lib, pkgs, ... }:

{
  fonts.packages = [
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    pkgs.nerd-fonts.noto
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.nerd-fonts.iosevka
  ];
}
