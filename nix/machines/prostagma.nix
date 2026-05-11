{
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  copypartyPort = 3210;
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  opencodePort = 4096;
  tunnelId = "56e33628-8005-4027-ae33-b55e7f0bd78b";
  tunnelCredsFile = "/var/lib/secrets/cloudflared/${tunnelId}.json";
  filesHostname = "files.cartermcbri.de";
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./hardware/prostagma.nix
    ./prostagma/app-storage.nix
    ./prostagma/bifrost.nix
    ./prostagma/migrated-apps.nix
  ];

  nix.settings.sandbox = false;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "plexmediaserver" ];
  nixpkgs.overlays = [ inputs.copyparty.overlays.default ];

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = true;
    privileged = true;
  };

  prostagma.appStorage = {
    enable = true;
    mode = "external";
  };

  prostagma.migratedApps = {
    enable = true;
    appRoot = "/srv/apps";
    mediaRoot = "/mnt/truenas/media-direct";
    syncthingDataRoot = "/mnt/truenas/syncthing-root";
    apps."qbittorrent-vpn".enable = true;
    apps.prowlarr.enable = true;
    apps.sonarr.enable = true;
    apps.radarr.enable = true;
    apps.komga.enable = true;
    apps.syncthing.enable = true;
  };

  virtualisation.docker.daemon.settings = {
    "data-root" = "/srv/apps/docker";
  };

  boot.supportedFilesystems = [ "nfs" ];

  environment.systemPackages = [
    pkgs.cfssl
    pkgs.cloudflared
    pkgs.copyparty
  ];

  networking.hostName = "prostagma";
  networking.firewall.allowedTCPPorts = [
    copypartyPort
    opencodePort
  ];

  systemd.tmpfiles.rules = [
    "d /mnt/truenas 0755 root root -"
    "d /mnt/truenas/media 0755 root root -"
    "d /mnt/truenas/media-direct 0755 root root -"
    "d /mnt/truenas/media-direct/tvshows 0755 root root -"
    "d /mnt/truenas/media-direct/movies 0755 root root -"
    "d /mnt/truenas/media-direct/comics 0755 root root -"
    "d /mnt/truenas/syncthing-root 0755 root root -"
    "d /mnt/truenas/syncthing-root/media 0755 root root -"
    "d /mnt/truenas/syncthing-root/media/games 0755 root root -"
    "d /mnt/truenas/syncthing-root/media/ebooks 0755 root root -"
    "d /mnt/truenas/syncthing-root/users 0755 root root -"
    "d /mnt/truenas/syncthing-root/users/carter 0755 root root -"
    "d /mnt/truenas/vm-data 0755 root root -"
    "d /mnt/truenas/photos 0755 root root -"
    "d /mnt/truenas/immich 0755 root root -"
  ];

  fileSystems."/mnt/truenas/media" = {
    device = "192.168.5.252:/mnt/reservoir/media";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/vm-data" = {
    device = "192.168.5.252:/mnt/river-rapid/vm-data";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/media-direct/tvshows" = {
    device = "192.168.5.252:/mnt/reservoir/media/tvshows";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/media-direct/movies" = {
    device = "192.168.5.252:/mnt/reservoir/media/movies";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/media-direct/comics" = {
    device = "192.168.5.252:/mnt/reservoir/media/comics";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/syncthing-root/media/games" = {
    device = "192.168.5.252:/mnt/reservoir/media/games";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/syncthing-root/media/ebooks" = {
    device = "192.168.5.252:/mnt/reservoir/media/ebooks";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/syncthing-root/users/carter" = {
    device = "192.168.5.252:/mnt/reservoir/users/carter";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/photos" = {
    device = "192.168.5.252:/mnt/reservoir/media/photos";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  fileSystems."/mnt/truenas/immich" = {
    device = "192.168.5.252:/mnt/reservoir/media/photos/immich";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30s"
    ];
  };

  services.fstrim.enable = false;
  services.dbus.implementation = "dbus";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    authKeyFile = "/run/secrets/tailscale_key";
  };

  systemd.services.opencode = {
    description = "opencode server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${opencode}/bin/opencode serve --hostname 0.0.0.0 --port ${toString opencodePort}";
      WorkingDirectory = "/root";
      Environment = [
        "HOME=/root"
        "PATH=/root/.local/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
  };

  services.postgresql.package = pkgs.postgresql_18;

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    mediaLocation = "/mnt/truenas/immich";
    group = "apps";
    accelerationDevices = [ "/dev/dri/renderD128" ];
    machine-learning.environment.MPLCONFIGDIR = "/var/cache/immich/matplotlib";
  };

  services.plex = {
    enable = true;
    openFirewall = true;
    user = "apps";
    group = "apps";
    dataDir = "/mnt/truenas/vm-data/plex/config";
    accelerationDevices = [ "/dev/dri/renderD128" ];
  };

  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = tunnelCredsFile;
      ingress = {
        ${filesHostname} = "http://127.0.0.1:${toString copypartyPort}";
      };
      default = "http_status:404";
    };
  };

  services.copyparty = {
    enable = true;
    user = "apps";
    group = "apps";
    settings = {
      i = "0.0.0.0";
      p = [ copypartyPort ];
      s = true;
      nih = true;
      vague-403 = true;
      no-dav = true;
      xff-hdr = "cf-connecting-ip";
      rproxy = 1;
      xff-src = [
        "127.0.0.1/32"
        "::1/128"
      ];
    };
    accounts = {
      haley.passwordFile = "/var/lib/secrets/copyparty/haley_password";
      carter.passwordFile = "/var/lib/secrets/copyparty/carter_password";
    };
    groups = {
      family = [ "haley" ];
      admins = [ "carter" ];
    };
    volumes = {
      "/media" = {
        path = "/mnt/truenas/media";
        access = {
          r = [ "@family" ];
          A = [ "@admins" ];
        };
      };
      "/media/photos" = {
        path = "/mnt/truenas/media/photos";
        access = {
          A = [ "@admins" ];
        };
      };
    };
  };

  users.groups.video.gid = lib.mkForce 44;
  users.groups.render.gid = lib.mkForce 993;
  users.groups.apps.gid = lib.mkForce 568;
  users.groups.media.gid = lib.mkForce 3004;

  users.users.apps = {
    isSystemUser = true;
    uid = 568;
    group = "apps";
    extraGroups = [
      "video"
      "render"
      "media"
    ];
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
    "media"
  ];

  system.stateVersion = "25.11";
}
