{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  hermes = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  obsidian-headless = self.packages.${pkgs.stdenv.hostPlatform.system}.obsidian-headless;
in
{
  home = {
    username = "carter";
    homeDirectory = "/home/carter";
    stateVersion = "26.11";
    packages = [
      hermes
      pkgs.age
      pkgs.fnox
      obsidian-headless
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
          HostName = "jerodmcbride-nas.dropbear-tortoise.ts.net";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
          SetEnv.TERM = "xterm-256color";
        };
        prostagma = {
          HostName = "prostagma.dropbear-tortoise.ts.net";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        rpi = {
          HostName = "raspberrypi.dropbear-tortoise.ts.net";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        scylla = {
          HostName = "scylla.dropbear-tortoise.ts.net";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
        truenas = {
          HostName = "192.168.5.252";
          User = "carter";
          IdentityFile = "~/.ssh/bitwarden";
          IdentitiesOnly = true;
        };
      };
    };
  };

  systemd.user.services.hermes-agent = {
    Unit = {
      Description = "Hermes Agent Gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${lib.getExe' pkgs.fnox "fnox"} exec --non-interactive -- ${hermes}/bin/hermes gateway run --replace";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "MESSAGING_CWD=${config.home.homeDirectory}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.hermes-dashboard = {
    Unit = {
      Description = "Hermes Agent Web Dashboard";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${hermes}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.obsidian-sync = {
    Unit = {
      Description = "Obsidian Notes vault sync";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/Documents/Notes";
    };
    Service = {
      ExecStart = "${obsidian-headless}/bin/ob sync --path ${config.home.homeDirectory}/Documents/Notes --continuous";
      WorkingDirectory = "${config.home.homeDirectory}/Documents/Notes";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
