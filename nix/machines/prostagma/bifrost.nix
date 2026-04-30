{ lib, pkgs, ... }:

{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.tmpfiles.rules = [
    "d /var/lib/bifrost 0750 root root -"
  ];

  virtualisation.oci-containers.containers.bifrost = {
    image = "maximhq/bifrost:latest";
    autoStart = true;

    ports = [
      "127.0.0.1:8080:8080"
    ];

    volumes = [
      "/var/lib/bifrost:/app/data"
    ];

    environment = {
      APP_HOST = "0.0.0.0";
      APP_PORT = "8080";
      LOG_LEVEL = "info";
    };

    environmentFiles = [
      "/var/lib/bifrost/bifrost.env"
    ];

    extraOptions = [
      "--pull=always"
      "--user=568:568"
      "--dns=100.100.100.100"
      "--dns=94.140.14.14"
    ];
  };

  systemd.services.docker-bifrost = {
    unitConfig.RequiresMountsFor = [
      "/mnt/truenas/vm-data/bifrost"
      "/var/lib/bifrost"
    ];

    preStart = ''
      ${pkgs.coreutils}/bin/install -d -o 568 -g 568 -m 0750 /var/lib/bifrost
      ${pkgs.util-linux}/bin/setpriv --reuid=568 --regid=568 --clear-groups \
        ${pkgs.coreutils}/bin/cat /mnt/truenas/vm-data/bifrost/config/config.json \
        > /var/lib/bifrost/config.json
      ${pkgs.util-linux}/bin/setpriv --reuid=568 --regid=568 --clear-groups \
        ${pkgs.coreutils}/bin/cat /mnt/truenas/vm-data/bifrost/secrets/bifrost.env \
        > /var/lib/bifrost/bifrost.env
      ${pkgs.coreutils}/bin/chown 568:568 /var/lib/bifrost/config.json /var/lib/bifrost/bifrost.env
      ${pkgs.coreutils}/bin/chmod 0640 /var/lib/bifrost/config.json /var/lib/bifrost/bifrost.env
    '';

    serviceConfig.Restart = lib.mkForce "always";
  };
}
