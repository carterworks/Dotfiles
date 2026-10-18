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
  opencode2 = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;

  opencode2Port = 49374;
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
      opencode2
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

  systemd.user.services.opencode2 = {
    Unit = {
      Description = "OpenCode 2 background server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      # `serve --service` runs the managed background server in the foreground,
      # which keeps its pairing password and local client registration stable
      # across restarts; systemd owns the lifecycle from here, so use
      # `systemctl --user stop opencode2` rather than `opencode2 service stop`.
      ExecStart = "${opencode2}/bin/opencode2 serve --service --hostname 0.0.0.0 --port ${toString opencode2Port}";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
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

  systemd.user.services.carter-nix-profile-prune = {
    Unit = {
      Description = "Prune old Carter Nix profile generations";
      ConditionPathExists = "${config.home.homeDirectory}/.local/state/nix/profiles/profile";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix profile wipe-history --profile ${config.home.homeDirectory}/.local/state/nix/profiles/profile --older-than 30d";
    };
  };

  systemd.user.timers.carter-nix-profile-prune = {
    Unit = {
      Description = "Weekly pruning of old Carter Nix profile generations";
    };
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "carter-nix-profile-prune.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
