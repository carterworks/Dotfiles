{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) obsidian-headless;
  vaultPath = "${config.home.homeDirectory}/Documents/Notes";
in
{
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ obsidian-headless ];

  systemd.user.services.obsidian-sync = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Obsidian Notes vault sync";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = vaultPath;
    };
    Service = {
      ExecStart = "${obsidian-headless}/bin/ob sync --path ${vaultPath} --continuous";
      WorkingDirectory = vaultPath;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
