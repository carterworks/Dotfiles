{
  config,
  fleet,
  lib,
  pkgs,
  ...
}:

let
  appRoot = "/srv/apps";
  mediaRoot = "/mnt/truenas/media-direct";
  sharedDataRoot = "/mnt/truenas/syncthing-root";
  torrentData = "/mnt/truenas/vm-data/qbittorrent-downloads";
  torrentConfig = "${appRoot}/qbittorrent-vpn/config";
  # Units that use the torrent payload fail closed when it is missing or backed
  # by anything other than this export.
  torrentDataMountSource = config.fileSystems."/mnt/truenas/vm-data".device;
  qbittorrentEnvFile = "/run/secrets/qbittorrent-vpn.env";

  uid = toString fleet.nasIds.apps;
  gid = toString fleet.nasIds.apps;

  appEnvironment = {
    GID = gid;
    GROUP_ID = gid;
    NVIDIA_VISIBLE_DEVICES = "void";
    PUID = uid;
    PGID = gid;
    TZ = "America/Denver";
    UID = uid;
    UMASK = "002";
    UMASK_SET = "002";
    USER_ID = uid;
  };

  appExtraOptions = [
    "--pull=missing"
    "--user=${uid}:${gid}"
    "--group-add=${toString fleet.nasIds.media}"
    "--cap-drop=ALL"
    "--security-opt=no-new-privileges=true"
  ];

  rootExtraOptions = [
    "--pull=missing"
  ];

  dockerNetwork = "prostagma-media";
  dockerSubnet = "172.30.0.0/24";
  lanNetwork = "192.168.4.0/22";
  # rpcbind and NFS. TrueNAS's mountd has no fixed port, and NFS needs 2049.
  nfsPorts = "111,2049";
  backrestPort = 9898;
  caddyAdminPort = 2019;

  # Backrest has its own uid so that no host service running as apps can
  # reach its mounts through /proc/<pid>/root.
  backrestId = toString config.users.users.backrest.uid;
  backrestExtraOptions = lib.remove "--user=${uid}:${gid}" appExtraOptions ++ [
    "--user=${backrestId}:${backrestId}"
    "--group-add=${toString fleet.nasIds.humans}"
  ];
  dockerNetworkOptions = [ "--network=${dockerNetwork}" ];
  dockerNetworkService = "docker-network-${dockerNetwork}.service";

  onDockerNetwork = {
    after = [ dockerNetworkService ];
    requires = [ dockerNetworkService ];
  };

  mkAppService =
    paths:
    onDockerNetwork
    // {
      unitConfig.RequiresMountsFor = paths;
      preStart =
        lib.concatStringsSep "\n" (
          map (path: ''
            if [ ! -e ${path} ]; then
              echo "Missing required migration path: ${path}" >&2
              exit 1
            fi
          '') paths
        )
        + lib.optionalString (builtins.elem torrentData paths) ''
          findmnt=${lib.getExe' pkgs.util-linux "findmnt"}
          actual_source=$("$findmnt" -n -o SOURCE -T ${torrentData})
          actual_fstype=$("$findmnt" -n -o FSTYPE -T ${torrentData})

          if [ "$actual_source" != ${torrentDataMountSource} ]; then
            echo "Torrent payload path ${torrentData} is backed by $actual_source, expected ${torrentDataMountSource}" >&2
            exit 1
          fi

          case "$actual_fstype" in
            nfs|nfs4) ;;
            *)
              echo "Torrent payload path ${torrentData} uses $actual_fstype, expected NFS" >&2
              exit 1
              ;;
          esac
        '';
    };

  mkArrContainer =
    {
      image,
      envPrefix,
      instanceName,
      port,
      volumes,
    }:
    {
      inherit image;
      autoStart = true;
      ports = [ "127.0.0.1:${toString port}:${toString port}/tcp" ];
      environment = appEnvironment // {
        "${envPrefix}__APP__INSTANCENAME" = instanceName;
        "${envPrefix}__SERVER__PORT" = toString port;
      };
      volumes = [ "${torrentData}:/data" ] ++ volumes;
      extraOptions = appExtraOptions ++ dockerNetworkOptions;
    };
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers = {
    "qbittorrent-vpn" = {
      image = "ghcr.io/binhex/arch-qbittorrentvpn:latest@sha256:211c5053fdf0eac2bea0f2cc2d85f7169356121f9ba9b29dcbfff0fa168dfbc6";
      autoStart = true;
      ports = [
        "127.0.0.1:38080:8080/tcp"
        "127.0.0.1:38118:8118/tcp"
        "127.0.0.1:39118:9118/tcp"
        "58946:58946/tcp"
        "58946:58946/udp"
      ];
      volumes = [
        "${torrentConfig}:/config"
        "${torrentData}:/data"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environment = appEnvironment // {
        LAN_NETWORK = "${lanNetwork},${dockerSubnet}";
        # Preserves the umask qBittorrent ran with as a TrueNAS app.
        UMASK = "000";
        UMASK_SET = "000";
        WEBUI_PORT = "8080";
      };
      environmentFiles = [ qbittorrentEnvFile ];
      extraOptions =
        rootExtraOptions
        ++ dockerNetworkOptions
        ++ [
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun:/dev/net/tun"
          "--hostname=qbittorrent"
          "--network-alias=qbittorrent-vpn"
        ];
    };

    prowlarr = mkArrContainer {
      image = "ghcr.io/home-operations/prowlarr:2.7.0.5723@sha256:fcf7498692f97698ea8b8f7078a0f81120a16e7354e4c232b5e3810e3e783dff";
      envPrefix = "PROWLARR";
      instanceName = "Prowlarr";
      port = 30050;
      volumes = [ "${appRoot}/prowlarr/config:/config" ];
    };

    # FlareSolverr lets Prowlarr reach Cloudflare-protected indexers (1337x and
    # friends) by solving their JS challenges. It runs as root because headless
    # Chrome needs more than the hardened appExtraOptions permit.
    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:v3.5.2@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767";
      autoStart = true;
      environment = appEnvironment // {
        LOG_LEVEL = "info";
      };
      extraOptions =
        rootExtraOptions
        ++ dockerNetworkOptions
        ++ [
          "--hostname=flaresolverr"
          "--network-alias=flaresolverr"
        ];
    };

    sonarr = mkArrContainer {
      image = "ghcr.io/home-operations/sonarr:4.0.20.3012@sha256:1f19eb5e0f421418c1a956bbe01310a0141423afe28bd9a4b1dcb8629ff2bce2";
      envPrefix = "SONARR";
      instanceName = "Sonarr";
      port = 30113;
      volumes = [
        "${appRoot}/sonarr/config:/config"
        "${mediaRoot}/tvshows:/tvshows"
      ];
    };

    radarr = mkArrContainer {
      image = "ghcr.io/home-operations/radarr:6.4.4.10685@sha256:1902ad2c08e9bac276ff9a1429af2eaa2f3c635a51f138f1b3eb734995171537";
      envPrefix = "RADARR";
      instanceName = "Radarr";
      port = 30025;
      volumes = [
        "${appRoot}/radarr/config:/config"
        "${mediaRoot}/movies:/movies"
      ];
    };

    bazarr = {
      image = "ghcr.io/home-operations/bazarr:1.6.2@sha256:6c40dfa683f767d28d1dc502837ed0a5a57682a84231f03e704e2b3f61b25a46";
      autoStart = true;
      ports = [ "127.0.0.1:6767:6767/tcp" ];
      environment = appEnvironment // {
        BAZARR__INSTANCE_NAME = "Bazarr";
        BAZARR__PORT = "6767";
      };
      volumes = [
        "${appRoot}/bazarr/config:/config"
        "${mediaRoot}/movies:/movies"
        "${mediaRoot}/tvshows:/tvshows"
      ];
      extraOptions = appExtraOptions ++ dockerNetworkOptions;
    };

    audiobookshelf = {
      # The official image has no PUID/PGID init, so identity comes from
      # --user in appExtraOptions and the media group comes from
      # --group-add, which is what grants read/write on the library.
      image = "ghcr.io/advplyr/audiobookshelf:2.38.0@sha256:60064c23f32fd9099fd39e82c5132c51701d1221135bbca04cd099b589e1edc3";
      autoStart = true;
      ports = [ "127.0.0.1:13378:13378/tcp" ];
      environment = appEnvironment // {
        # The image defaults to PORT=80, which a non-root process cannot
        # bind, so the listener must be moved to the unprivileged port.
        PORT = "13378";
      };
      volumes = [
        "${appRoot}/audiobookshelf/config:/config"
        "${appRoot}/audiobookshelf/metadata:/metadata"
        "${mediaRoot}/audiobooks:/audiobooks"
      ];
      extraOptions = appExtraOptions ++ dockerNetworkOptions;
    };

    backrest = {
      image = "garethgeorge/backrest:latest@sha256:b852979754281026230cc69fb11428e6d57c9a97784ab4a444ffc7934c53a215";
      autoStart = true;
      ports = [ "127.0.0.1:${toString backrestPort}:${toString backrestPort}/tcp" ];
      environment = appEnvironment // {
        BACKREST_CONFIG = "/config/config.json";
        BACKREST_DATA = "/data";
        # This is the bind *inside* the container's own network
        # namespace, so it must accept the docker proxy's connection. The
        # port is published on the host's loopback, and the firewall below
        # lets only Caddy and root connect to it.
        BACKREST_PORT = "0.0.0.0:${toString backrestPort}";
        XDG_CACHE_HOME = "/cache";
        TMPDIR = "/tmp";
      };
      volumes = [
        "${appRoot}/backrest/config:/config"
        "${appRoot}/backrest/data:/data"
        "${appRoot}/backrest/cache:/cache"
        "${appRoot}/backrest/tmp:/tmp"
        "${mediaRoot}/audiobooks:/userdata/reservoir/media/audiobooks:ro"
        "${mediaRoot}/comics:/userdata/reservoir/media/comics:ro"
        "${mediaRoot}/tvshows:/userdata/reservoir/media/tvshows:ro"
        "${mediaRoot}/movies:/userdata/reservoir/media/movies:ro"
        "${sharedDataRoot}/media/ebooks:/userdata/reservoir/media/ebooks:ro"
        "${sharedDataRoot}/media/games:/userdata/reservoir/media/games:ro"
        "/mnt/truenas/photos:/userdata/reservoir/media/photos:ro"
        # Read-only: restores are downloaded from Backrest's web page
        # (docs/truenas.md).
        "/mnt/truenas/private/users:/userdata/reservoir/users:ro"
      ];
      extraOptions = backrestExtraOptions ++ dockerNetworkOptions;
    };
  };

  # Bazarr asks Jellyfin, which runs on the host, to rescan an item after each
  # subtitle change. Jellyfin listens on every interface, so only the container
  # network is let in rather than opening the port to the LAN.
  #
  # TrueNAS trusts prostagma's address, so anything here that can send NFS
  # from a low port can claim any user, and the users export maps everyone to
  # root. Containers can bind low ports, so they send no NFS at all; on the
  # host only root and the kernel's own NFS client may.
  #
  # Backrest has no login of its own and can read every home, so only Caddy,
  # behind Authelia, and root may reach it. Caddy's admin API has no login
  # either and could route around Authelia, so only Caddy and root may reach
  # that too.
  #
  # There are no stop commands: NixOS runs them at the start of every reload
  # and after a failed start, which would leave these rules off.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s ${dockerSubnet} -p tcp --dport 8096 -j nixos-fw-accept

    iptables -N prostagma-containers 2>/dev/null || iptables -F prostagma-containers
    for proto in tcp udp; do
      iptables -A prostagma-containers -p "$proto" -m multiport --dports ${nfsPorts} -j REJECT
    done
    iptables -A prostagma-containers -p tcp --dport ${toString backrestPort} -j REJECT
    iptables -N DOCKER-USER 2>/dev/null || true
    iptables -C DOCKER-USER -j prostagma-containers 2>/dev/null || iptables -I DOCKER-USER -j prostagma-containers

    # Each family separately: ip46tables reports only ip6tables' status.
    for ipt in iptables ip6tables; do
      $ipt -N prostagma-local 2>/dev/null || $ipt -F prostagma-local
      for port in ${toString backrestPort} ${toString caddyAdminPort}; do
        $ipt -A prostagma-local -p tcp --dport "$port" -m owner --uid-owner caddy -j RETURN
        $ipt -A prostagma-local -p tcp --dport "$port" -m owner --uid-owner 1-4294967294 -j REJECT
      done
      for proto in tcp udp; do
        $ipt -A prostagma-local -p "$proto" -m multiport --dports ${nfsPorts} -m owner --uid-owner 1-4294967294 -j REJECT
      done
      $ipt -C OUTPUT -j prostagma-local 2>/dev/null || $ipt -I OUTPUT -j prostagma-local
    done
  '';

  systemd.tmpfiles.rules =
    map (dir: "d ${appRoot}/${dir} 0775 ${uid} ${gid} -") [
      "bazarr/config"
      "audiobookshelf/config"
      "audiobookshelf/metadata"
    ]
    ++ map (dir: "d ${appRoot}/${dir} 0775 backrest backrest -") [
      "backrest/cache"
      "backrest/tmp"
    ]
    # Backrest ran as apps until it got its own uid. Restores land in its
    # storage with their original modes, so no other local user may enter.
    ++ [
      "d ${appRoot}/backrest 0700 backrest backrest -"
      "Z ${appRoot}/backrest - backrest backrest -"
    ];

  users.users.backrest = {
    isSystemUser = true;
    uid = 970;
    group = "backrest";
  };
  users.groups.backrest.gid = 970;

  systemd.services = {
    "docker-network-${dockerNetwork}" = {
      description = "Docker network for migrated media containers";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker=${pkgs.docker}/bin/docker
        network=${dockerNetwork}
        subnet=${dockerSubnet}

        if "$docker" network inspect "$network" >/dev/null 2>&1; then
          existing_subnet=$("$docker" network inspect --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$network")
          if [ "$existing_subnet" != "$subnet" ]; then
            echo "Docker network $network already exists with subnet $existing_subnet, expected $subnet" >&2
            exit 1
          fi
        else
          "$docker" network create --subnet "$subnet" "$network"
        fi
      '';
    };

    "docker-qbittorrent-vpn" = mkAppService [
      torrentConfig
      torrentData
      qbittorrentEnvFile
      "/dev/net/tun"
    ];

    prostagma-qbittorrent-space-guard = {
      description = "Stop qBittorrent before Prostagma storage is exhausted";
      after = [ "docker-qbittorrent-vpn.service" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "180s";
      };
      script = ''
        set -u

        docker=${lib.getExe pkgs.docker}
        findmnt=${lib.getExe' pkgs.util-linux "findmnt"}
        stat=${lib.getExe' pkgs.coreutils "stat"}
        systemctl=${lib.getExe' pkgs.systemd "systemctl"}
        timeout=${lib.getExe' pkgs.coreutils "timeout"}
        warn_bytes=$((30 * 1024 * 1024 * 1024))
        stop_bytes=$((20 * 1024 * 1024 * 1024))
        must_stop=0

        check_path() {
          path=$1
          label=$2

          if ! blocks=$("$timeout" -k 2 10 "$stat" -f -c %a "$path"); then
            echo "$label storage probe failed at $path" >&2
            must_stop=1
            return
          fi
          if ! block_size=$("$timeout" -k 2 10 "$stat" -f -c %S "$path"); then
            echo "$label block-size probe failed at $path" >&2
            must_stop=1
            return
          fi

          available=$((blocks * block_size))
          if [ "$available" -lt "$stop_bytes" ]; then
            echo "$label storage critically low: $available bytes available at $path" >&2
            must_stop=1
          elif [ "$available" -lt "$warn_bytes" ]; then
            echo "$label storage low: $available bytes available at $path" >&2
          fi
        }

        check_path ${appRoot} application

        actual_source=unknown
        actual_fstype=unknown
        if ! actual_source=$("$timeout" -k 2 10 "$findmnt" -n -o SOURCE -T ${torrentData}); then
          echo "Torrent payload mount source probe failed at ${torrentData}" >&2
          must_stop=1
        elif [ "$actual_source" != ${torrentDataMountSource} ]; then
          echo "Torrent payload mount mismatch: got $actual_source, expected ${torrentDataMountSource}" >&2
          must_stop=1
        fi

        if ! actual_fstype=$("$timeout" -k 2 10 "$findmnt" -n -o FSTYPE -T ${torrentData}); then
          echo "Torrent payload filesystem probe failed at ${torrentData}" >&2
          must_stop=1
        else
          case "$actual_fstype" in
            nfs|nfs4) ;;
            *)
              echo "Torrent payload filesystem mismatch: got $actual_fstype, expected NFS" >&2
              must_stop=1
              ;;
          esac
        fi

        check_path ${torrentData} torrent

        if [ "$must_stop" -eq 1 ]; then
          running=$("$timeout" -k 2 10 "$docker" container inspect -f '{{.State.Running}}' qbittorrent-vpn 2>/dev/null || true)
          if [ "$running" = true ]; then
            if ! "$timeout" -k 2 15 "$docker" exec qbittorrent-vpn curl -fsS --max-time 10 -X POST \
              -d hashes=all \
              http://127.0.0.1:8080/api/v2/torrents/stop; then
              echo "qBittorrent API stop failed; stopping its systemd unit" >&2
            fi
          fi
          "$systemctl" --no-block stop docker-qbittorrent-vpn.service
        fi
      '';
    };

    docker-prowlarr = mkAppService [
      "${appRoot}/prowlarr/config"
      torrentData
    ];

    docker-flaresolverr = onDockerNetwork;

    docker-sonarr = mkAppService [
      "${appRoot}/sonarr/config"
      "${mediaRoot}/tvshows"
      torrentData
    ];

    docker-radarr = mkAppService [
      "${appRoot}/radarr/config"
      "${mediaRoot}/movies"
      torrentData
    ];

    docker-bazarr =
      mkAppService [
        "${appRoot}/bazarr/config"
        "${mediaRoot}/movies"
        "${mediaRoot}/tvshows"
      ]
      // {
        after = [
          dockerNetworkService
          "docker-radarr.service"
          "docker-sonarr.service"
        ];
      };

    docker-audiobookshelf = mkAppService [
      "${appRoot}/audiobookshelf/config"
      "${appRoot}/audiobookshelf/metadata"
      "${mediaRoot}/audiobooks"
    ];

    docker-backrest = mkAppService [
      "${appRoot}/backrest/config/config.json"
      "${appRoot}/backrest/data"
      "${appRoot}/backrest/cache"
      "${appRoot}/backrest/tmp"
      "${mediaRoot}/audiobooks"
      "${mediaRoot}/comics"
      "${mediaRoot}/tvshows"
      "${mediaRoot}/movies"
      "${sharedDataRoot}/media/ebooks"
      "${sharedDataRoot}/media/games"
      "/mnt/truenas/photos"
      "/mnt/truenas/private/users"
    ];
  };

  systemd.timers.prostagma-qbittorrent-space-guard = {
    description = "Check Prostagma app and torrent storage headroom";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "1m";
      Persistent = true;
      Unit = "prostagma-qbittorrent-space-guard.service";
    };
  };

  dotfiles.fnox.secrets.QBITTORRENT_VPN_ENV = {
    path = qbittorrentEnvFile;
    mode = "0600";
    requiredBy = [ "docker-qbittorrent-vpn.service" ];
  };
}
