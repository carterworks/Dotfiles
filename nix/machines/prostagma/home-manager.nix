{
  config,
  inputs,
  pkgs,
  self,
  ...
}:

let
  obsidian-headless = self.packages.${pkgs.stdenv.hostPlatform.system}.obsidian-headless;
  opencode2 = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
in
{
  imports = [ ../../users/carter/agent-daemons.nix ];

  home = {
    username = "carter";
    homeDirectory = "/home/carter";
    stateVersion = "26.11";
    packages = [
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
      ExecStart = "${pkgs.nix}/bin/nix-env --profile ${config.home.homeDirectory}/.local/state/nix/profiles/profile --delete-generations +5";
    };
  };

  systemd.user.timers.carter-nix-profile-prune = {
    Unit = {
      Description = "Daily pruning of old Carter Nix profile generations";
    };
    Timer = {
      OnCalendar = "02:45";
      Persistent = true;
      RandomizedDelaySec = "10m";
      Unit = "carter-nix-profile-prune.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
