{
  config,
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

  uid = "568";
  gid = "568";

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
    "--group-add=3004"
    "--cap-drop=ALL"
    "--security-opt=no-new-privileges=true"
  ];

  rootExtraOptions = [
    "--pull=missing"
  ];

  dockerNetwork = "prostagma-media";
  dockerSubnet = "172.30.0.0/24";
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
      image = "ghcr.io/binhex/arch-qbittorrentvpn:latest@sha256:202f2fbbd5d70b2a57ce4fafdd22ef12af2f64ca2f87b277ea7456fe37c9063d";
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
        LAN_NETWORK = "192.168.4.0/22,${dockerSubnet}";
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
      image = "ghcr.io/home-operations/prowlarr:2.3.4.5307@sha256:4df82f58d39fde43a206c4bba126226b63ecf2394df202e94c31afc9faae3ed9";
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
      image = "ghcr.io/home-operations/sonarr:4.0.17.2950@sha256:bdc787fe07bb7c0b6af9c030764902f70092ec9a426e52a36716d3a13917fe2d";
      envPrefix = "SONARR";
      instanceName = "Sonarr";
      port = 30113;
      volumes = [
        "${appRoot}/sonarr/config:/config"
        "${mediaRoot}/tvshows:/tvshows"
      ];
    };

    radarr = mkArrContainer {
      image = "ghcr.io/home-operations/radarr:6.1.1.10317@sha256:5e08c0eefd2770d1d29395c4f84fe5bf7dfc3a986598021306a5d8ac017a3989";
      envPrefix = "RADARR";
      instanceName = "Radarr";
      port = 30025;
      volumes = [
        "${appRoot}/radarr/config:/config"
        "${mediaRoot}/movies:/movies"
      ];
    };

    bazarr = {
      image = "ghcr.io/home-operations/bazarr:1.6.0@sha256:133a3064b0b9ea18ad66cc88b6863f91b9c05dc32212805843fcfce4c4b8eb05";
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
      image = "ghcr.io/advplyr/audiobookshelf:2.36.1@sha256:3528a93b6442ffe54bd46771bbbab7c97084e1101071586d9dc2254f30bb4358";
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
      image = "garethgeorge/backrest:latest@sha256:9c9966b5c285ec791a6b06cb4545fa0247424d05442e12f9558b4322d9f8a15f";
      autoStart = true;
      ports = [ "127.0.0.1:9898:9898/tcp" ];
      environment = appEnvironment // {
        BACKREST_CONFIG = "/config/config.json";
        BACKREST_DATA = "/data";
        # This is the bind *inside* the container's own network
        # namespace, so it must accept the docker proxy's connection.
        # Exposure is restricted by the published port below, which is
        # bound to the host's loopback.
        BACKREST_PORT = "0.0.0.0:9898";
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
        "${sharedDataRoot}/users/carter:/userdata/reservoir/users/carter:ro"
      ];
      extraOptions = appExtraOptions ++ [ "--group-add=3000" ] ++ dockerNetworkOptions;
    };
  };

  systemd.tmpfiles.rules = map (dir: "d ${appRoot}/${dir} 0775 ${uid} ${gid} -") [
    "bazarr/config"
    "audiobookshelf/config"
    "audiobookshelf/metadata"
    "backrest/cache"
    "backrest/tmp"
  ];

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
      "${sharedDataRoot}/users/carter"
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
