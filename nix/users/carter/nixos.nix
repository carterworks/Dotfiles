{ pkgs, ... }:

{
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "Bibata-Modern-Classic";
    HYPRCURSOR_THEME = "24";
  };

  programs.fish.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  };

  users.groups.games = { };
  users.users.carter = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "games"
    ];
  };
}
