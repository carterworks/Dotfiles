{
  lib,
  pkgs,
  ...
}:

let
  dataDir = "/srv/apps/podmaker/data";

  # The GHCR package is private. Docker on this host is not logged in to the
  # registry, so deploy the image by building it on the host from a git archive
  # of the PodMaker repository, then restart docker-podmaker.
  image = "ghcr.io/carterworks/podmaker:latest";
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
      PUBLIC_BASE_URL = "https://podmaker.dropbear-tortoise.ts.net";
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
    unitConfig.RequiresMountsFor = [ dataDir ];
    preStart = ''
      if ! ${lib.getExe pkgs.docker} image inspect ${image} >/dev/null 2>&1; then
        echo "PodMaker image is not loaded on this host." >&2
        echo "Build it from the PodMaker repository and load it before restarting docker-podmaker." >&2
        exit 1
      fi
    '';
  };
}
