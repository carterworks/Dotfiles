{ config, pkgs, ... }:

let
  profile = "${config.home.homeDirectory}/.local/state/nix/profiles/profile";
in
{
  # The system nix-gc runs as root and never prunes this per-user profile, so
  # without this its generations pin every old closure in the store.
  systemd.user.services.nix-profile-prune = {
    Unit = {
      Description = "Prune old Nix user profile generations";
      ConditionPathExists = profile;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix-env --profile ${profile} --delete-generations +5";
    };
  };

  systemd.user.timers.nix-profile-prune = {
    Unit.Description = "Daily pruning of old Nix user profile generations";
    Timer = {
      # Before the system nix-gc at 03:15, so it collects what this frees.
      OnCalendar = "02:45";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
