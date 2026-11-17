{
  fleet,
  lib,
  pkgs,
  ...
}:

let
  inherit (fleet) tailnetDomain;
  dataDir = "/srv/apps/podmaker/data";

  # The GHCR package is private. Docker on this host is not logged in to the
  # registry, so deploy the image by building it on the host from a git archive
  # of the PodMaker repository, then restart docker-podmaker.
  image = "ghcr.io/carterworks/podmaker:latest";

  # Kokoro reads PodMaker's articles aloud. It is reachable only from PodMaker
  # over their own network; nothing publishes it on the host.
  kokoroImage = "ghcr.io/remsky/kokoro-fastapi-cpu:v0.10.0@sha256:f54c5960c2b9387f6349080a9944f8bc7e8cdb98a4ef9238cb0b0f9ff9795f44";
  network = "podmaker";
  networkService = "docker-network-${network}.service";

  hardening = [
    "--cap-drop=ALL"
    "--security-opt=no-new-privileges=true"
  ];
in
{
  systemd.tmpfiles.rules = [
    "d /srv/apps/podmaker 0755 568 568 -"
    "d ${dataDir} 0755 568 568 -"
  ];

  virtualisation.oci-containers.containers.podmaker = {
    inherit image;
    autoStart = true;
    ports = [ "127.0.0.1:8090:8080/tcp" ];
    volumes = [ "${dataDir}:/data" ];
    environment = {
      PUBLIC_BASE_URL = "https://podmaker.${tailnetDomain}";
      PODCAST_TITLE = "PodMaker";
      PODCAST_AUTHOR = "Carter McBride";
      TTS_LOCAL_URL = "http://kokoro:8880/v1";
    };
    extraOptions = [
      "--pull=never"
      "--user=568:568"
      "--network=${network}"
    ]
    ++ hardening;
  };

  virtualisation.oci-containers.containers.kokoro = {
    image = kokoroImage;
    autoStart = true;
    extraOptions = [
      "--network=${network}"
      "--network-alias=kokoro"
      # Synthesis runs near real time on all four cores; a low weight lets
      # it use idle CPU while Jellyfin and Immich win any contention.
      "--cpu-shares=256"
      "--memory=3g"
    ]
    ++ hardening;
  };

  systemd.services = {
    "docker-network-${network}" = {
      description = "Docker network shared by PodMaker and its speech engine";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.getExe pkgs.docker} network inspect ${network} >/dev/null 2>&1 \
          || ${lib.getExe pkgs.docker} network create ${network}
      '';
    };

    docker-podmaker = {
      after = [
        "prostagma-app-storage.service"
        networkService
      ];
      requires = [
        "prostagma-app-storage.service"
        networkService
      ];
      unitConfig.RequiresMountsFor = [ dataDir ];
      preStart = ''
        if ! ${lib.getExe pkgs.docker} image inspect ${image} >/dev/null 2>&1; then
          echo "PodMaker image is not loaded on this host." >&2
          echo "Build it from the PodMaker repository and load it before restarting docker-podmaker." >&2
          exit 1
        fi
      '';
    };

    docker-kokoro = {
      after = [ networkService ];
      requires = [ networkService ];
    };
  };
}
