{ config, lib, ... }:

let
  cfg = config.prostagma.appStorage;
in
{
  options.prostagma.appStorage = {
    enable = lib.mkEnableOption "a dedicated virtual disk for prostagma app state";

    mode = lib.mkOption {
      type = lib.types.enum [
        "external"
        "mount"
      ];
      default = "external";
      description = ''
        How /srv/apps is provided. Use "external" for a Proxmox LXC mount point
        or bind mount, and "mount" when NixOS should mount a block device itself.
      '';
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/srv/apps";
      description = "Mount point for app config and state moved off the root filesystem.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-label/prostagma-apps";
      description = "Stable block device path for the app-state virtual disk.";
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "ext4";
      description = "Filesystem type for the app-state virtual disk.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.mode != "mount" || cfg.device != "";
            message = "prostagma.appStorage.device must be set when mode is \"mount\".";
          }
        ];

        systemd.tmpfiles.rules = [
          "d ${cfg.mountPoint} 0755 root root -"
        ];
      }
      (lib.mkIf (cfg.mode == "mount") {
        fileSystems.${cfg.mountPoint} = {
          inherit (cfg) device fsType;
          options = [
            "nofail"
            "x-systemd.device-timeout=30s"
          ];
        };
      })
    ]
  );
}
