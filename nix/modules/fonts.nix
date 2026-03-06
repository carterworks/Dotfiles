{ lib, pkgs, ... }:

{
  fonts.packages = [
    pkgs.iosevka-bin
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    pkgs.nerd-fonts.noto
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.inter
    pkgs.nerd-fonts.iosevka
  ];
}
