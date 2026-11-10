{
  lib,
  pkgs,
  ...
}:

let
  # A Proxmox LXC mount point provides this; NixOS only verifies it is mounted.
  mountPoint = "/srv/apps";
in
{
  systemd.services.prostagma-app-storage = {
    description = "Validate Prostagma app storage";
    before = [ "docker.service" ];
    unitConfig.RequiresMountsFor = [ mountPoint ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.util-linux "mountpoint"} --quiet ${mountPoint}";
    };
  };

  systemd.services.docker = {
    after = [ "prostagma-app-storage.service" ];
    requires = [ "prostagma-app-storage.service" ];
  };
}
