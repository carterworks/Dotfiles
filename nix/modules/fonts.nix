{ lib, pkgs, ... }:

{
  fonts.packages =
    lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      pkgs.nerd-fonts.noto
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.nerd-fonts.iosevka
    ];
}
