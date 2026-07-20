{
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  copypartyPort = 3210;
  koreaderSyncPort = 17200;
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
              <li><a href="http://prostagma.${tailnetDomain}:9898/">Backrest</a></li>
              <li><a href="http://prostagma.${tailnetDomain}:${toString copypartyPort}/">Copyparty</a></li>
              <li><a href="https://immich.${tailnetDomain}/">Immich</a></li>
              <li><a href="https://komga.${tailnetDomain}/">Komga</a></li>
              <li><a href="http://prostagma.${tailnetDomain}:32400/web/">Plex</a></li>
              <li><a href="https://prowlarr.${tailnetDomain}/">Prowlarr</a></li>
              <li><a href="https://qbittorrent.${tailnetDomain}/">qBittorrent</a></li>
              <li><a href="https://radarr.${tailnetDomain}/">Radarr</a></li>
              <li><a href="https://sonarr.${tailnetDomain}/">Sonarr</a></li>
              <li><a href="https://syncthing.${tailnetDomain}/">Syncthing</a></li>
            </ul>
          </nav>

          <section aria-labelledby="api-health-heading">
            <h2 id="api-health-heading">API health</h2>
            <ul>
              <li>
                Immich Machine Learning:
                <output class="status" data-health-url="/health/immich-ml" data-state="checking" aria-live="polite">Checking…</output>
              </li>
              <li>
                KOReader Sync:
                <output class="status" data-health-url="/health/koreader-sync" data-state="checking" aria-live="polite">Checking…</output>
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

    handle /health/koreader-sync {
      rewrite * /healthcheck
      reverse_proxy 127.0.0.1:${toString koreaderSyncPort} {
        header_up Accept application/vnd.koreader.v1+json
      }
    }

    handle {
      root * ${prostagmaDirectory}
      file_server
    }
  '';
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./hardware/prostagma.nix
    ./prostagma/app-storage.nix
    ./prostagma/migrated-apps.nix
  ];

  nix.settings.sandbox = false;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 7d";
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
    syncthingDataRoot = "/mnt/truenas/syncthing-root";
    apps."qbittorrent-vpn".enable = true;
    apps.prowlarr.enable = true;
    apps.sonarr.enable = true;
    apps.radarr.enable = true;
    apps.komga.enable = true;
    apps.syncthing.enable = true;
    apps.backrest.enable = true;
    apps."koreader-sync-server".enable = true;
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
  ];

  systemd.tmpfiles.rules = [
    "d /mnt/truenas 0755 root root -"
    "d /mnt/truenas/media 0755 root root -"
    "d /mnt/truenas/media-direct 0755 root root -"
    "d /mnt/truenas/media-direct/tvshows 0755 root root -"
    "d /mnt/truenas/media-direct/movies 0755 root root -"
    "d /mnt/truenas/media-direct/comics 0755 root root -"
    "d /mnt/truenas/media-direct/audiobooks 0755 root root -"
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

  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://prostagma.localhost".extraConfig = prostagmaSiteConfig;
      "http://prostagma.${tailnetDomain}".extraConfig = prostagmaSiteConfig;
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

      "$tailscale" serve clear svc:bifrost
      "$tailscale" serve --bg --https=443 http://127.0.0.1:80
      "$tailscale" serve --service=svc:immich --https=443 http://127.0.0.1:2283
      "$tailscale" serve --service=svc:qbittorrent --https=443 http://127.0.0.1:38080
      "$tailscale" serve --service=svc:sonarr --https=443 http://127.0.0.1:30113
      "$tailscale" serve --service=svc:radarr --https=443 http://127.0.0.1:30025
      "$tailscale" serve --service=svc:prowlarr --https=443 http://127.0.0.1:30050
      "$tailscale" serve --service=svc:komga --https=443 http://127.0.0.1:30048
      "$tailscale" serve --service=svc:syncthing --https=443 http://127.0.0.1:20910
      "$tailscale" serve --service=svc:koreader-sync --https=443 http://127.0.0.1:17200
    '';
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

  users.users.carter = {
    isNormalUser = true;
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
