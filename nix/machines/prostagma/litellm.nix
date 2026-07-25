{ lib, pkgs, ... }:

let
  appRoot = "/srv/apps/litellm";
  configFile = "${appRoot}/config.yaml";
  environmentFile = "/var/lib/secrets/litellm.env";
in
{
  virtualisation.oci-containers.containers.litellm = {
    image = "docker.litellm.ai/berriai/litellm-database:latest@sha256:789b94dc1abae5cb487d6419bbac3920a37fe1c4746db0e5fdc6a7b772fb8b95";
    autoStart = true;
    cmd = [
      "--config"
      "/etc/litellm/config.yaml"
      "--port"
      "4000"
    ];
    ports = [ "127.0.0.1:4000:4000/tcp" ];
    environmentFiles = [ environmentFile ];
    volumes = [ "${configFile}:/etc/litellm/config.yaml:ro" ];
  };

  systemd.services.docker-litellm = {
    unitConfig.RequiresMountsFor = [ appRoot ];
    postStart = ''
      docker=${pkgs.docker}/bin/docker

      for _ in {1..30}; do
        if "$docker" exec --user 0 litellm apk add --no-cache nodejs npm; then
          exit 0
        fi
        sleep 1
      done

      exit 1
    '';
    preStart = ''
      test -f ${lib.escapeShellArg configFile}
      test -f ${lib.escapeShellArg environmentFile}
    '';
  };
}
