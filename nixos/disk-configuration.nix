{
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WDC_WDS100T2B0C_21323D801784";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        options = {
          # Workaround: cannot import 'zroot': I/O error in disko tests
          cachefile = "none";
          ashift = "12";
        };
        rootFsOptions = {
          compression = "zstd";
          mountpoint = "none";
          acltype = "posixacl";
          xattr = "sa";
        };
        mountpoint = "/";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

        datasets = {
          "ROOT" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "ROOT/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          "data" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "data/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
          "data/games" = {
            type = "zfs_fs";
            mountpoint = "/games";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}
