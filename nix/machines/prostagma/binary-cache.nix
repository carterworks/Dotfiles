{ pkgs, ... }:

let
  port = 8199;
  host = "prostagma.dropbear-tortoise.ts.net:${toString port}";
  storage = "/srv/apps/attic";
  secretFile = "/var/lib/secrets/attic/environment";
in
{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "atticd" ];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  services.atticd = {
    enable = true;
    environmentFile = secretFile;
    settings = {
      listen = "[::]:${toString port}";
      allowed-hosts = [ host ];
      api-endpoint = "http://${host}/";
      database.url = "postgresql:///atticd?host=/run/postgresql&user=atticd";
      storage = {
        type = "local";
        path = storage;
      };
      # The default level 8 is too slow for this host when CI pushes a closure.
      compression = {
        type = "zstd";
        level = 3;
      };
      garbage-collection.default-retention-period = "14 days";
    };
  };

  # The module's DynamicUser adopts an existing user of this name. Without one,
  # a reassigned UID would leave the storage directory unwritable, because it
  # lives outside the StateDirectory that systemd re-chowns.
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };
  users.groups.atticd = { };

  systemd.tmpfiles.rules = [ "d ${storage} 0750 atticd atticd -" ];

  systemd.services.atticd-secret = {
    description = "Generate the Attic token signing secret";
    unitConfig.ConditionPathExists = "!${secretFile}";
    path = [ pkgs.openssl ];
    serviceConfig.Type = "oneshot";
    script = ''
      umask 077
      install -d -m 0700 "$(dirname ${secretFile})"
      secret="$(openssl genrsa -traditional 4096 | base64 -w0)"
      printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=%s\n' "$secret" > ${secretFile}.tmp
      mv ${secretFile}.tmp ${secretFile}
    '';
  };

  systemd.services.atticd = {
    after = [
      "atticd-secret.service"
      "prostagma-app-storage.service"
    ];
    requires = [
      "atticd-secret.service"
      "prostagma-app-storage.service"
    ];
    unitConfig.RequiresMountsFor = [ storage ];
  };

  # atticd has no way to bind to an address that only exists once tailscaled is
  # up, so it listens everywhere and this interface rule is what keeps the port
  # off the LAN. Tailscale Serve would need another line in the
  # tailscale-services unit, whose `serve reset` owns all of the node's routes.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}
