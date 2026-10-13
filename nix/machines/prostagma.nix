{
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  copypartyPort = 3210;

  tailnetDomain = "dropbear-tortoise.ts.net";
  tunnelId = "56e33628-8005-4027-ae33-b55e7f0bd78b";
  tunnelCredsFile = "/var/lib/secrets/cloudflared/${tunnelId}.json";
  filesHostname = "files.cartermcbri.de";

  prostagmaDirectory = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Prostagma services</title>
        <style>
          :root {
            color-scheme: light dark;
            font-family: system-ui, sans-serif;
          }

          body {
            margin: 2rem auto;
            max-width: 40rem;
            padding: 0 1rem;
          }

          li {
            margin-block: 0.5rem;
          }

          .status {
            align-items: center;
            display: inline-flex;
            font-size: 0.875rem;
            gap: 0.4rem;
          }

          .status::before {
            background: #888;
            border-radius: 50%;
            content: "";
            height: 0.65rem;
            width: 0.65rem;
          }

          .status[data-state="healthy"]::before {
            background: #22a447;
          }

          .status[data-state="unhealthy"]::before {
            background: #d33c32;
          }
        </style>
      </head>
      <body>
        <header>
          <h1>Prostagma services</h1>
        </header>
        <main>
          <nav aria-label="Prostagma services">
            <ul>
              <!--
                Audiobookshelf bakes /audiobookshelf into its client bundle
                (<base href> and asset paths), so that prefix is the canonical
                URL. The bare host still renders, but its login callback is
                rejected as being outside the router base path, which breaks
                the SSO button.
              -->
              <li><a href="https://audiobookshelf.${tailnetDomain}/audiobookshelf/">Audiobookshelf</a></li>
              <li><a href="https://backrest.${tailnetDomain}/">Backrest</a></li>
              <li><a href="https://bazarr.${tailnetDomain}/">Bazarr</a></li>
              <li><a href="http://prostagma.${tailnetDomain}:${toString copypartyPort}/">Copyparty</a></li>
              <li><a href="http://prostagma.${tailnetDomain}:9119/">Hermes Agent</a></li>
              <li><a href="https://immich.${tailnetDomain}/">Immich</a></li>

              <li><a href="https://jellyfin.${tailnetDomain}/">Jellyfin</a></li>
              <li><a href="http://prostagma.${tailnetDomain}:32400/web/">Plex</a></li>
              <li><a href="https://prowlarr.${tailnetDomain}/">Prowlarr</a></li>
              <li><a href="https://qbittorrent.${tailnetDomain}/">qBittorrent</a></li>
              <li><a href="https://radarr.${tailnetDomain}/">Radarr</a></li>
              <li><a href="https://sonarr.${tailnetDomain}/">Sonarr</a></li>

            </ul>
          </nav>

          <section aria-labelledby="api-health-heading">
            <h2 id="api-health-heading">API health</h2>
            <ul>
              <li>
                Immich Machine Learning:
                <output class="status" data-health-url="/health/immich-ml" data-state="checking" aria-live="polite">Checking…</output>
              </li>

            </ul>
          </section>
        </main>
        <script>
          const checks = document.querySelectorAll("[data-health-url]");

          async function checkHealth(status) {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 5000);

            status.dataset.state = "checking";
            status.textContent = "Checking…";

            try {
              const response = await fetch(status.dataset.healthUrl, {
                cache: "no-store",
                signal: controller.signal,
              });

              if (!response.ok) {
                throw new Error("Health check returned " + response.status);
              }

              status.dataset.state = "healthy";
              status.textContent = "Healthy";
            } catch (error) {
              status.dataset.state = "unhealthy";
              status.textContent = "Unavailable";
            } finally {
              clearTimeout(timeout);
            }
          }

          function checkAll() {
            checks.forEach(checkHealth);
          }

          checkAll();
          setInterval(checkAll, 30000);
        </script>
      </body>
    </html>
  '';

  prostagmaSiteConfig = ''
    bind 127.0.0.1 ::1

    handle /health/immich-ml {
      rewrite * /ping
      reverse_proxy 127.0.0.1:3003
    }


    handle {
      root * ${prostagmaDirectory}
      file_server
    }
  '';

  hermesDashboardSiteConfig = ''
    bind 100.96.32.111
    reverse_proxy 127.0.0.1:9119 {
      header_up Host 127.0.0.1:9119
    }
  '';
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./hardware/prostagma.nix
    ./prostagma/app-storage.nix

    ./prostagma/migrated-apps.nix
    ./prostagma/sso.nix
  ];

  home-manager.users.carter = import ./prostagma/hermes-carter.nix;

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    settings = {
      auto-optimise-store = true;
      sandbox = false;
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 10 * 1024 * 1024 * 1024;
    };
  };

  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    SystemKeepFree = "5G";
  };

  nixpkgs.config.allowUnfree = true;
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
    torrentDataRoot = "/mnt/truenas/vm-data/qbittorrent-downloads";
    torrentDataMountSource = "192.168.5.252:/mnt/river-rapid/vm-data";
    sharedDataRoot = "/mnt/truenas/syncthing-root";
    apps."qbittorrent-vpn".enable = true;
    apps.prowlarr.enable = true;
    apps.sonarr.enable = true;
    apps.radarr.enable = true;
    apps.bazarr.enable = true;
    apps.audiobookshelf.enable = true;

    apps.backrest.enable = true;

  };

  virtualisation.docker = {
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--filter=until=168h" ];
    };
    daemon.settings = {
      "data-root" = "/srv/apps/docker";
    };
  };

  boot.supportedFilesystems = [ "nfs" ];

  environment.systemPackages = [
    pkgs.cfssl
    pkgs.cloudflared
    pkgs.copyparty
  ];

  networking.hostName = "prostagma";
  networking.hosts."100.91.175.4" = [ "homeassistant.local" ];
  networking.firewall.allowedTCPPorts = [
    copypartyPort
  ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    9119
  ];

  # The /mnt/truenas exports root-squash root, so tmpfiles must never create,
  # chmod or chown anything there: a single failure makes systemd-tmpfiles
  # exit non-zero, which aborts switch-to-configuration *after* it has already
  # stopped changed units, leaving them stopped.
  #
  # Rules here exist mainly to neutralise rules that app modules generate from
  # their own options. systemd-tmpfiles deduplicates per path *and* type, with
  # the first (highest-precedence) file winning, so an override must repeat the
  # module's own type or both will run. `d` with "-" metadata only ever changes
  # what is missing, which is a no-op when the directory already exists.
  #
  # Do not reintroduce an "A+" rule here: this export does not support POSIX
  # ACLs, so setfacl fails with EOPNOTSUPP after walking ~500k entries on every
  # activation. The copyparty service user can already read that directory.
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/bazarr 0700 root root -"

    # Local directories on the container root filesystem (mountpoint parents).
    "d /mnt/truenas 0755 root root -"
    "d /mnt/truenas/media-direct 0755 root root -"
    "d /mnt/truenas/syncthing-root 0755 root root -"
    "d /mnt/truenas/syncthing-root/media 0755 root root -"
    "d /mnt/truenas/syncthing-root/users 0755 root root -"
    "d /srv/apps/immich-cache 0750 immich apps -"

    # NFS-backed paths and the directories inside them: verify only.
    "d /mnt/truenas/media - - - -"
    "e /mnt/truenas/media-direct/tvshows - - - -"
    "e /mnt/truenas/media-direct/movies - - - -"
    "e /mnt/truenas/media-direct/comics - - - -"
    "e /mnt/truenas/media-direct/audiobooks - - - -"
    "e /mnt/truenas/syncthing-root/media/games - - - -"
    "e /mnt/truenas/syncthing-root/media/ebooks - - - -"
    "d /mnt/truenas/syncthing-root/users/carter - - - -"
    "e /mnt/truenas/vm-data - - - -"
    "d /mnt/truenas/vm-data/jellyfin - - - -"
    "e /mnt/truenas/photos - - - -"
    "e /mnt/truenas/immich - - - -"
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

  fileSystems."/mnt/truenas/media-direct/audiobooks" = {
    device = "192.168.5.252:/mnt/reservoir/media/audiobooks";
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

  programs.nix-ld.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitEmptyPasswords = "no";
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    authKeyFile = "/run/secrets/tailscale_key";
  };

  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://prostagma.localhost".extraConfig = prostagmaSiteConfig;
      "http://prostagma.${tailnetDomain}".extraConfig = prostagmaSiteConfig;
      "http://prostagma.${tailnetDomain}:9119".extraConfig = hermesDashboardSiteConfig;
    };
  };

  systemd.services.tailscale-services = {
    description = "Configure Tailscale Services for prostagma apps";
    after = [
      "caddy.service"
      "tailscaled.service"
    ];
    requires = [
      "caddy.service"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      tailscale=${pkgs.tailscale}/bin/tailscale

      "$tailscale" serve reset
      "$tailscale" serve --bg --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:jellyfin --https=443 http://127.0.0.1:8096
      "$tailscale" serve --service=svc:immich --https=443 http://127.0.0.1:2283
      # These are gated: Caddy on 127.0.0.1:80 performs the Authelia
      # forward-auth check and then proxies to the application's own loopback
      # port. Pointing Serve at the application directly would bypass the
      # gate, and every application port is loopback-only with no firewall
      # allowance, so Serve is the sole ingress.
      "$tailscale" serve --service=svc:bazarr --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:qbittorrent --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:sonarr --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:radarr --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:prowlarr --https=443 http://127.0.0.1:80

      # Not gated: Audiobookshelf authenticates with OIDC instead, and the
      # media servers have no proxy-auth mode.
      "$tailscale" serve --service=svc:audiobookshelf --https=443 http://127.0.0.1:13378

      # Authelia portal and OpenID Connect issuer. Applications in
      # containers call the token endpoint server-side over the tailnet
      # address, which is why 8443 is also allowed through the firewall.
      "$tailscale" serve --bg --https=8443 http://127.0.0.1:9091

      # Authelia as a Tailscale Service: the MagicDNS name without a port,
      # which is the issuer prefix for OpenID Connect clients.
      "$tailscale" serve --service=svc:authelia --https=443 http://127.0.0.1:9091

      # Backrest, gated like the others. Kept last because the unit runs under
      # `set -e` and this Service needs admin approval in the tailnet before the
      # route is accepted; a failure here must not strand the routes above.
      "$tailscale" serve --service=svc:backrest --https=443 http://127.0.0.1:80



    '';
  };

  services.postgresql = {
    package = pkgs.postgresql_18;
    dataDir = "/srv/apps/postgresql/18";
  };
  systemd.services.postgresql = {
    after = [ "prostagma-app-storage.service" ];
    requires = [ "prostagma-app-storage.service" ];
    unitConfig.RequiresMountsFor = [ "/srv/apps/postgresql/18" ];
  };

  services.immich = {
    enable = true;
    # Reached through Tailscale Serve on loopback, so keep the listener off
    # every other interface: a LAN- or tailnet-reachable port would bypass any
    # authentication layer placed in front of the proxy.
    host = "127.0.0.1";
    mediaLocation = "/mnt/truenas/immich";
    group = "apps";
    accelerationDevices = [ "/dev/dri/renderD128" ];
    machine-learning.environment = {
      MACHINE_LEARNING_CACHE_FOLDER = lib.mkForce "/srv/apps/immich-cache";
      XDG_CACHE_HOME = lib.mkForce "/srv/apps/immich-cache";
      MPLCONFIGDIR = lib.mkForce "/srv/apps/immich-cache/matplotlib";
    };
  };
  systemd.services.immich-machine-learning = {
    after = [ "prostagma-app-storage.service" ];
    requires = [ "prostagma-app-storage.service" ];
    unitConfig.RequiresMountsFor = [ "/srv/apps/immich-cache" ];
  };
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ "/mnt/truenas/immich" ];

  # Intel iGPU drivers for jellyfin QSV transcodes (and immich machine learning).
  # libva and libvpl find these via /run/opengl-driver, which hardware.graphics
  # creates; it must come from the module system, not from plex's bundled libs.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-compute-runtime
    ];
  };

  services.plex = {
    enable = true;
    openFirewall = true;
    user = "apps";
    group = "apps";
    dataDir = "/mnt/truenas/vm-data/plex/config";
    accelerationDevices = [ "/dev/dri/renderD128" ];
  };
  systemd.services.plex.unitConfig.RequiresMountsFor = [ "/mnt/truenas/vm-data/plex/config" ];

  services.jellyfin = {
    enable = true;
    # Jellyfin 12 has no bind-address option, so it still listens on 0.0.0.0;
    # keeping the port closed at the firewall is what makes the Tailscale
    # route the only way in.
    user = "apps";
    group = "apps";
    dataDir = "/mnt/truenas/vm-data/jellyfin";
    cacheDir = "/mnt/truenas/vm-data/jellyfin/cache";
    hardwareAcceleration = {
      enable = true;
      type = "qsv";
      device = "/dev/dri/renderD128";
    };
    # Transcoding options below were applied via forceEncodingConfig once;
    # Jellyfin 12 rewrites encoding.xml on every start, so with the flag left
    # on it churns out a new backup file on each restart. The settings also
    # re-apply on fresh installs because the module seeds encoding.xml from
    # these options; after that the dashboard owns the file.
    # forceEncodingConfig = true;
    transcoding = {
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        mpeg2 = true;
        vc1 = true;
        vp8 = true;
        vp9 = true;
        av1 = true;
        hevc10bit = true;
      };
      enableHardwareEncoding = true;
      hardwareEncodingCodecs.hevc = true;
      enableIntelLowPowerEncoding = true;
    };
  };
  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/mnt/truenas/vm-data/jellyfin" ];
  # The module's tmpfiles rules run before the NFS mounts are up at boot, and
  # the service's WorkingDirectory must exist before preStart runs, so create
  # the data directories in a dedicated oneshot (same reason plex does).
  systemd.services.jellyfin-dirs = {
    description = "Create Jellyfin data directories on NFS storage";
    unitConfig.RequiresMountsFor = [ "/mnt/truenas/vm-data" ];
    # The vm-data NFS export root-squashes, but the parent directory is
    # group-writable by apps, so create the directories as that user.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "apps";
      Group = "apps";
    };
    script = ''
      install -d -m 0700 \
        /mnt/truenas/vm-data/jellyfin/config \
        /mnt/truenas/vm-data/jellyfin/log \
        /mnt/truenas/vm-data/jellyfin/cache
    '';
  };
  systemd.services.jellyfin = {
    after = [ "jellyfin-dirs.service" ];
    requires = [ "jellyfin-dirs.service" ];
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
      opds = true;
      xff-hdr = "cf-connecting-ip";
      rproxy = 1;
      xff-src = [
        "127.0.0.1/32"
        "::1/128"
      ];
    };
    accounts = {
      alex.passwordFile = "/var/lib/secrets/copyparty/alex_password";
      haley.passwordFile = "/var/lib/secrets/copyparty/haley_password";
      carter.passwordFile = "/var/lib/secrets/copyparty/carter_password";
    };
    groups = {
      family = [
        "haley"
        "alex"
      ];
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
      # A "/media/photos" volume pointing at /mnt/truenas/media/photos was
      # removed: that path cannot exist (the media export is root-squashed, so
      # nothing here can create directories inside it) and no client ever used
      # it. Point a volume at /mnt/truenas/photos instead if the photos export
      # should be served, and provision that directory as the service user.
      "/users/carter" = {
        path = "/mnt/truenas/syncthing-root/users/carter";
        access = {
          A = [ "carter" ];
        };
      };
    };
  };
  systemd.services.copyparty.unitConfig.RequiresMountsFor = [
    "/mnt/truenas/media"
    "/mnt/truenas/syncthing-root/users/carter"
  ];

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

  users.users.carter = {
    isNormalUser = true;
    linger = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR4/6L4CG8EylhmV7laHQyn81YfQTk63tKWP4y9GB2O carter@bitwarden"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "carter" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users.users.immich.extraGroups = [
    "video"
    "render"
    "media"
  ];

  system.stateVersion = "25.11";
}
