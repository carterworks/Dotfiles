{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    optionalString
    optionals
    types
    ;

  cfg = config.prostagma.migratedApps;

  appNames = [
    "qbittorrent-vpn"
    "prowlarr"
    "sonarr"
    "radarr"
    "komga"
    "syncthing"
    "backrest"
    "koreader-sync-server"
  ];

  appRoot = cfg.appRoot;
  mediaRoot = cfg.mediaRoot;
  uid = toString cfg.uid;
  gid = toString cfg.gid;
  appUser = "${uid}:${gid}";

  appEnvironment = {
    GID = gid;
    GROUP_ID = gid;
    NVIDIA_VISIBLE_DEVICES = "void";
    PUID = uid;
    PGID = gid;
    TZ = cfg.timeZone;
    UID = uid;
    UMASK = cfg.umask;
    UMASK_SET = cfg.umask;
    USER_ID = uid;
  };

  appExtraOptions = [
    "--pull=missing"
    "--user=${appUser}"
    "--group-add=${toString cfg.mediaGid}"
    "--cap-drop=ALL"
    "--security-opt=no-new-privileges=true"
  ];

  rootExtraOptions = [
    "--pull=missing"
  ];

  mkPathCheckService = paths: {
    unitConfig.RequiresMountsFor = paths;
    preStart =
      concatStringsSep "\n" (
        map (path: ''
          if [ ! -e ${lib.escapeShellArg path} ]; then
            echo "Missing required migration path: ${path}" >&2
            exit 1
          fi
        '') paths
      )
      + optionalString (builtins.elem torrentData paths && cfg.torrentDataMountSource != null) ''
        findmnt=${lib.getExe' pkgs.util-linux "findmnt"}
        actual_source=$("$findmnt" -n -o SOURCE -T ${lib.escapeShellArg torrentData})
        actual_fstype=$("$findmnt" -n -o FSTYPE -T ${lib.escapeShellArg torrentData})

        if [ "$actual_source" != ${lib.escapeShellArg cfg.torrentDataMountSource} ]; then
          echo "Torrent payload path ${torrentData} is backed by $actual_source, expected ${cfg.torrentDataMountSource}" >&2
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

  torrentData = cfg.torrentDataRoot;
  torrentConfig = "${appRoot}/qbittorrent-vpn/config";
  dockerNetworkOptions = optionals cfg.dockerNetwork.enable [
    "--network=${cfg.dockerNetwork.name}"
  ];
  dockerNetworkService = "docker-network-${cfg.dockerNetwork.name}.service";
  dockerNetworkDependencies = optional cfg.dockerNetwork.enable dockerNetworkService;

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
  options.prostagma.migratedApps = {
    enable = mkEnableOption "draft TrueNAS app migration containers";

    apps = lib.genAttrs appNames (name: {
      enable = mkEnableOption "the migrated ${name} container";
    });

    appRoot = mkOption {
      type = types.str;
      default = "/mnt/truenas/vm-data";
      description = "Root containing migrated app state and config directories.";
    };

    mediaRoot = mkOption {
      type = types.str;
      default = "/mnt/truenas/media";
      description = "Root containing media libraries exposed to media apps.";
    };

    torrentDataRoot = mkOption {
      type = types.str;
      default = "${config.prostagma.migratedApps.appRoot}/qbittorrent-vpn/data";
      description = "Bulk qBittorrent payload root mounted into qBittorrent and Arr containers as /data.";
    };

    torrentDataMountSource = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Expected NFS source backing torrentDataRoot; when set, application units fail closed on a missing or wrong mount.";
    };

    torrentSpaceGuard = {
      warningGiB = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Log a warning when app or torrent storage has less than this many GiB available.";
      };

      stopGiB = mkOption {
        type = types.ints.positive;
        default = 20;
        description = "Stop all qBittorrent transfers when app or torrent storage has less than this many GiB available.";
      };
    };

    syncthingDataRoot = mkOption {
      type = types.str;
      default = "/mnt/truenas/reservoir";
      description = "Host path mounted into Syncthing as /data.";
    };

    qbittorrentEnvFile = mkOption {
      type = types.str;
      default = "/var/lib/secrets/qbittorrent-vpn.env";
      description = "Environment file containing VPN/provider settings for binhex qBittorrent VPN.";
    };

    qbittorrentUmask = mkOption {
      type = types.str;
      default = "000";
      description = "UMASK for qBittorrent, preserving the current TrueNAS app behavior.";
    };

    lanCidrs = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.4.0/22" ];
      description = "LAN CIDRs allowed through the qBittorrent VPN container firewall.";
    };

    dockerNetwork = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Create a dedicated Docker network for the migrated media containers.";
      };

      name = mkOption {
        type = types.str;
        default = "prostagma-media";
        description = "Docker network used by qBittorrent, Prowlarr, Sonarr, Radarr, Komga, and Syncthing.";
      };

      subnet = mkOption {
        type = types.str;
        default = "172.30.0.0/24";
        description = "IPv4 subnet for the migrated media Docker network.";
      };
    };

    uid = mkOption {
      type = types.int;
      default = 568;
      description = "UID used by apps migrated from TrueNAS.";
    };

    gid = mkOption {
      type = types.int;
      default = 568;
      description = "GID used by apps migrated from TrueNAS.";
    };

    mediaGid = mkOption {
      type = types.int;
      default = 3004;
      description = "Supplementary media group GID used for shared media access.";
    };

    timeZone = mkOption {
      type = types.str;
      default = "America/Denver";
      description = "Timezone passed to migrated containers.";
    };

    umask = mkOption {
      type = types.str;
      default = "002";
      description = "Default umask passed to app containers that support it.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkDefault true;
    virtualisation.oci-containers.backend = lib.mkDefault "docker";

    virtualisation.oci-containers.containers =
      optionalAttrs cfg.apps."qbittorrent-vpn".enable {
        "qbittorrent-vpn" = {
          image = "ghcr.io/binhex/arch-qbittorrentvpn:latest@sha256:202f2fbbd5d70b2a57ce4fafdd22ef12af2f64ca2f87b277ea7456fe37c9063d";
          autoStart = true;
          ports = [
            "127.0.0.1:38080:8080/tcp"
            "38118:8118/tcp"
            "39118:9118/tcp"
            "58946:58946/tcp"
            "58946:58946/udp"
          ];
          volumes = [
            "${torrentConfig}:/config"
            "${torrentData}:/data"
            "/etc/localtime:/etc/localtime:ro"
          ];
          environment = appEnvironment // {
            LAN_NETWORK = concatStringsSep "," (
              cfg.lanCidrs ++ optional cfg.dockerNetwork.enable cfg.dockerNetwork.subnet
            );
            UMASK = cfg.qbittorrentUmask;
            UMASK_SET = cfg.qbittorrentUmask;
            WEBUI_PORT = "8080";
          };
          environmentFiles = [ cfg.qbittorrentEnvFile ];
          extraOptions =
            rootExtraOptions
            ++ dockerNetworkOptions
            ++ [
              "--cap-add=NET_ADMIN"
              "--device=/dev/net/tun:/dev/net/tun"
              "--hostname=qbittorrent"
            ]
            ++ optional cfg.dockerNetwork.enable "--network-alias=qbittorrent-vpn";
        };
      }
      // optionalAttrs cfg.apps.prowlarr.enable {
        prowlarr = mkArrContainer {
          image = "ghcr.io/home-operations/prowlarr:2.3.4.5307@sha256:4df82f58d39fde43a206c4bba126226b63ecf2394df202e94c31afc9faae3ed9";
          envPrefix = "PROWLARR";
          instanceName = "Prowlarr";
          port = 30050;
          volumes = [ "${appRoot}/prowlarr/config:/config" ];
        };
      }
      // optionalAttrs cfg.apps.sonarr.enable {
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
      }
      // optionalAttrs cfg.apps.radarr.enable {
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
      }
      // optionalAttrs cfg.apps.komga.enable {
        komga = {
          image = "gotson/komga:1.24.1@sha256:a84a0424e2f8235ba9373ed10b9b903e0feecdbb500a1b4aebac01f08e9e57db";
          autoStart = true;
          ports = [ "127.0.0.1:30048:30048/tcp" ];
          environment = appEnvironment // {
            KOMGA_CONFIGDIR = "/config";
            KOMGA_DATABASE_FILE = "/config/database.sqlite";
            SERVER_PORT = "30048";
            SERVER_SERVLET_CONTEXT_PATH = "/";
          };
          volumes = [
            "${appRoot}/komga:/config"
            "${mediaRoot}/comics:/data/comics"
          ];
          extraOptions = appExtraOptions ++ dockerNetworkOptions;
        };
      }
      // optionalAttrs cfg.apps.syncthing.enable {
        syncthing = {
          image = "syncthing/syncthing:2.0.15@sha256:37c0e031d9f5559dfa416f0f9157509277d97a24abd0ad27590bd92a91616ecc";
          autoStart = true;
          cmd = [ "--allow-newer-config" ];
          ports = [
            "127.0.0.1:20910:8384/tcp"
            "20978:22000/tcp"
            "20979:22000/udp"
          ];
          environment = appEnvironment // {
            PCAP = "cap_sys_admin,cap_chown,cap_dac_override,cap_fowner+ep";
            STGUIADDRESS = "0.0.0.0:8384";
            STNOUPGRADE = "true";
          };
          volumes = [
            "${cfg.syncthingDataRoot}:/data"
            "${appRoot}/syncthing/config:/var/syncthing"
          ];
          extraOptions =
            rootExtraOptions
            ++ dockerNetworkOptions
            ++ [
              "--cap-drop=ALL"
              "--cap-add=CHOWN"
              "--cap-add=DAC_OVERRIDE"
              "--cap-add=FOWNER"
              "--cap-add=SETFCAP"
              "--cap-add=SETGID"
              "--cap-add=SETPCAP"
              "--cap-add=SETUID"
              "--cap-add=SYS_ADMIN"
            ];
        };
      }
      // optionalAttrs cfg.apps.backrest.enable {
        backrest = {
          image = "garethgeorge/backrest:latest@sha256:9c9966b5c285ec791a6b06cb4545fa0247424d05442e12f9558b4322d9f8a15f";
          autoStart = true;
          ports = [ "9898:9898/tcp" ];
          environment = appEnvironment // {
            BACKREST_CONFIG = "/config/config.json";
            BACKREST_DATA = "/data";
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
            "${cfg.syncthingDataRoot}/media/ebooks:/userdata/reservoir/media/ebooks:ro"
            "${cfg.syncthingDataRoot}/media/games:/userdata/reservoir/media/games:ro"
            "/mnt/truenas/photos:/userdata/reservoir/media/photos:ro"
            "${cfg.syncthingDataRoot}/users/carter:/userdata/reservoir/users/carter:ro"
          ];
          extraOptions = appExtraOptions ++ [ "--group-add=3000" ] ++ dockerNetworkOptions;
        };
      }
      // optionalAttrs cfg.apps."koreader-sync-server".enable {
        "koreader-sync-server" = {
          image = "koreader/kosync:latest@sha256:bb3f13615365703315a43b9059f65e71e876440f867e23a42bf27f2fa18264e1";
          autoStart = true;
          ports = [ "127.0.0.1:17200:17200/tcp" ];
          volumes = [
            "${appRoot}/koreader-sync-server/logs/app:/app/koreader-sync-server/logs"
            "${appRoot}/koreader-sync-server/logs/redis:/var/log/redis"
            "${appRoot}/koreader-sync-server/data/redis:/var/lib/redis"
          ];
          extraOptions = rootExtraOptions ++ dockerNetworkOptions;
        };
      };

    systemd.tmpfiles.rules =
      optional cfg.apps.backrest.enable ("d ${appRoot}/backrest/cache 0775 ${uid} ${gid} -")
      ++ optional cfg.apps.backrest.enable ("d ${appRoot}/backrest/tmp 0775 ${uid} ${gid} -")
      ++ optional cfg.apps."koreader-sync-server".enable (
        "d ${appRoot}/koreader-sync-server/logs/app 0755 root root -"
      )
      ++ optional cfg.apps."koreader-sync-server".enable (
        "d ${appRoot}/koreader-sync-server/logs/redis 0755 root root -"
      )
      ++ optional cfg.apps."koreader-sync-server".enable (
        "d ${appRoot}/koreader-sync-server/data/redis 0755 root root -"
      );

    systemd.services =
      optionalAttrs cfg.dockerNetwork.enable {
        "docker-network-${cfg.dockerNetwork.name}" = {
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
            network=${lib.escapeShellArg cfg.dockerNetwork.name}
            subnet=${lib.escapeShellArg cfg.dockerNetwork.subnet}

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
      }
      // optionalAttrs cfg.apps."qbittorrent-vpn".enable {
        "docker-qbittorrent-vpn" =
          mkPathCheckService [
            torrentConfig
            torrentData
            cfg.qbittorrentEnvFile
            "/dev/net/tun"
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs (cfg.apps."qbittorrent-vpn".enable && cfg.torrentDataMountSource != null) {
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
            warn_bytes=$((${toString cfg.torrentSpaceGuard.warningGiB} * 1024 * 1024 * 1024))
            stop_bytes=$((${toString cfg.torrentSpaceGuard.stopGiB} * 1024 * 1024 * 1024))
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

            check_path ${lib.escapeShellArg appRoot} application

            actual_source=unknown
            actual_fstype=unknown
            if ! actual_source=$("$timeout" -k 2 10 "$findmnt" -n -o SOURCE -T ${lib.escapeShellArg torrentData}); then
              echo "Torrent payload mount source probe failed at ${torrentData}" >&2
              must_stop=1
            elif [ "$actual_source" != ${lib.escapeShellArg cfg.torrentDataMountSource} ]; then
              echo "Torrent payload mount mismatch: got $actual_source, expected ${cfg.torrentDataMountSource}" >&2
              must_stop=1
            fi

            if ! actual_fstype=$("$timeout" -k 2 10 "$findmnt" -n -o FSTYPE -T ${lib.escapeShellArg torrentData}); then
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

            check_path ${lib.escapeShellArg torrentData} torrent

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
      }
      // optionalAttrs cfg.apps.prowlarr.enable {
        docker-prowlarr =
          mkPathCheckService [
            "${appRoot}/prowlarr/config"
            torrentData
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps.sonarr.enable {
        docker-sonarr =
          mkPathCheckService [
            "${appRoot}/sonarr/config"
            "${mediaRoot}/tvshows"
            torrentData
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps.radarr.enable {
        docker-radarr =
          mkPathCheckService [
            "${appRoot}/radarr/config"
            "${mediaRoot}/movies"
            torrentData
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps.komga.enable {
        docker-komga =
          mkPathCheckService [
            "${appRoot}/komga"
            "${mediaRoot}/comics"
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps.syncthing.enable {
        docker-syncthing =
          mkPathCheckService [
            "${appRoot}/syncthing/config"
            cfg.syncthingDataRoot
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps.backrest.enable {
        docker-backrest =
          mkPathCheckService [
            "${appRoot}/backrest/config/config.json"
            "${appRoot}/backrest/data"
            "${appRoot}/backrest/cache"
            "${appRoot}/backrest/tmp"
            "${mediaRoot}/audiobooks"
            "${mediaRoot}/comics"
            "${mediaRoot}/tvshows"
            "${mediaRoot}/movies"
            "${cfg.syncthingDataRoot}/media/ebooks"
            "${cfg.syncthingDataRoot}/media/games"
            "/mnt/truenas/photos"
            "${cfg.syncthingDataRoot}/users/carter"
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      }
      // optionalAttrs cfg.apps."koreader-sync-server".enable {
        "docker-koreader-sync-server" =
          mkPathCheckService [
            "${appRoot}/koreader-sync-server/logs/app"
            "${appRoot}/koreader-sync-server/logs/redis"
            "${appRoot}/koreader-sync-server/data/redis"
          ]
          // {
            after = dockerNetworkDependencies;
            requires = dockerNetworkDependencies;
          };
      };

    systemd.timers.prostagma-qbittorrent-space-guard =
      mkIf (cfg.apps."qbittorrent-vpn".enable && cfg.torrentDataMountSource != null)
        {
          description = "Check Prostagma app and torrent storage headroom";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2m";
            OnUnitActiveSec = "1m";
            Persistent = true;
            Unit = "prostagma-qbittorrent-space-guard.service";
          };
        };

    assertions = [
      {
        assertion = cfg.torrentSpaceGuard.warningGiB > cfg.torrentSpaceGuard.stopGiB;
        message = "prostagma.migratedApps.torrentSpaceGuard.warningGiB must exceed stopGiB";
      }
    ];
  };
}
