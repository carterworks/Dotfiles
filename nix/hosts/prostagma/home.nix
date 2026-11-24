{
  config,
  fleet,
  pkgs,
  ...
}:

let
  inherit (fleet) tailnetDomain;
in
{
  imports = [
    ../../modules/home/nix-profile-prune.nix
    ../../modules/home/obsidian-sync.nix
  ];

  home = {
    username = "carter";
    homeDirectory = "/home/carter";
    stateVersion = "26.11";
    packages = [
      pkgs.age
      pkgs.fnox
    ];
  };

  programs = {
    home-manager.enable = true;
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        herodotus = {
          HostName = "192.168.5.253";
          User = "root";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        jerodmcbride-nas = {
          HostName = "jerodmcbride-nas.${tailnetDomain}";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
          SetEnv.TERM = "xterm-256color";
        };
        prostagma = {
          HostName = "prostagma.${tailnetDomain}";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        rpi = {
          HostName = "raspberrypi.${tailnetDomain}";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        scylla = {
          HostName = "scylla.${tailnetDomain}";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        truenas = {
          HostName = fleet.lan.truenas;
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
      };
    };
  };
}
