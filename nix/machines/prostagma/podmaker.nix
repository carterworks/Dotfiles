{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.prostagma.podmaker;
  tailnetDomain = "dropbear-tortoise.ts.net";

  # The GHCR package is private. Docker on this host is not logged in to the
  # registry, so deploy the image by building it on the host from a git archive
  # of the PodMaker repository, then restart docker-podmaker.
  image = "ghcr.io/carterworks/podmaker:latest";
in
{
  options.prostagma.podmaker = {
    enable = lib.mkEnableOption "PodMaker private podcast feeds";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "Loopback port for the PodMaker container.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/apps/podmaker/data";
      description = "Host directory mounted at /data in the PodMaker container.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /srv/apps/podmaker 0755 568 568 -"
      "d ${cfg.dataDir} 0755 568 568 -"
    ];

    virtualisation.oci-containers.containers.podmaker = {
      inherit image;
      autoStart = true;
      ports = [ "127.0.0.1:${toString cfg.port}:8080/tcp" ];
      volumes = [ "${cfg.dataDir}:/data" ];
      environment = {
        PUBLIC_BASE_URL = "https://podmaker.${tailnetDomain}";
        PODCAST_TITLE = "PodMaker";
        PODCAST_AUTHOR = "Carter McBride";
      };
      extraOptions = [
        "--pull=never"
        "--user=568:568"
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges=true"
      ];
    };

    systemd.services.docker-podmaker = {
      after = [ "prostagma-app-storage.service" ];
      requires = [ "prostagma-app-storage.service" ];
      unitConfig.RequiresMountsFor = [ cfg.dataDir ];
      preStart = ''
        if ! ${lib.getExe pkgs.docker} image inspect ${image} >/dev/null 2>&1; then
          echo "PodMaker image is not loaded on this host." >&2
          echo "Build it from the PodMaker repository and load it before restarting docker-podmaker." >&2
          exit 1
        fi
      '';
    };
  };
}
