{ lib, pkgs, ... }:

let
  appRoot = "/srv/apps/litellm";
  environmentFile = "/var/lib/secrets/litellm.env";
  network = "prostagma-litellm";
in
{
  virtualisation.oci-containers.containers = {
    litellm = {
      image = "docker.litellm.ai/berriai/litellm-database:latest@sha256:789b94dc1abae5cb487d6419bbac3920a37fe1c4746db0e5fdc6a7b772fb8b95";
      autoStart = true;
      ports = [ "127.0.0.1:4000:4000/tcp" ];
      environment = {
        DATABASE_URL = "postgresql://litellm:litellm@litellm-postgres:5432/litellm";
        STORE_MODEL_IN_DB = "True";
      };
      environmentFiles = [ environmentFile ];
      extraOptions = [ "--network=${network}" ];
    };

    "litellm-postgres" = {
      image = "postgres:16@sha256:da8cf245a60506e50a0a8cbb0f39c559ca622d92490605b67fcadc74ca1ea8e4";
      autoStart = true;
      environment = {
        POSTGRES_DB = "litellm";
        POSTGRES_PASSWORD = "litellm";
        POSTGRES_USER = "litellm";
      };
      volumes = [ "${appRoot}/postgres:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=${network}" ];
    };
  };

  systemd.tmpfiles.rules = [ "d ${appRoot}/postgres 0700 root root -" ];

  systemd.services = {
    "docker-network-${network}" = {
      description = "Docker network for LiteLLM";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker=${pkgs.docker}/bin/docker

        if ! "$docker" network inspect ${lib.escapeShellArg network} >/dev/null 2>&1; then
          "$docker" network create ${lib.escapeShellArg network}
        fi
      '';
    };

    docker-litellm-postgres = {
      after = [ "docker-network-${network}.service" ];
      requires = [ "docker-network-${network}.service" ];
      unitConfig.RequiresMountsFor = [ appRoot ];
    };

    docker-litellm = {
      after = [ "docker-litellm-postgres.service" ];
      requires = [ "docker-litellm-postgres.service" ];
      preStart = ''
        docker=${pkgs.docker}/bin/docker

        test -f ${lib.escapeShellArg environmentFile}
        for _ in {1..10}; do
          if "$docker" exec litellm-postgres pg_isready -U litellm; then
            exit 0
          fi
          sleep 5
        done

        exit 1
      '';
    };
  };
}
