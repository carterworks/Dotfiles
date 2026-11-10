{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (import ../../lib/fleet.nix) tailnetDomain;
  hub = config.services.beszel.hub;
  dataDir = "/srv/apps/beszel-hub";
  # The hub syncs its systems from config.yml on every start and deletes any
  # system not listed, so this list is the whole fleet; see "Add a host" in
  # docs/monitoring.md.
  agents = [
    "prostagma"
    "scylla"
    "eltoro"
  ];
  systemsEnabled = config.dotfiles.beszel.hubKey != null;

  # Caddy's logs record request headers and redact only Cookie and
  # Authorization, while each agent sends its token in X-Token: on every
  # connection to the access log, and on every upstream error to the journal.
  withoutToken = ''
    format filter {
      wrap json
      request>headers>X-Token delete
    }
  '';

  # The first migration creates the account that the proxy's header logs in
  # to, and a superuser of the same address. Password logins are off, so the
  # random password is never stored anywhere.
  prepare = pkgs.writeShellScript "beszel-hub-prepare" ''
    set -euo pipefail
    USER_EMAIL=carter@carter.works USER_PASSWORD="$(${lib.getExe pkgs.openssl} rand -base64 32)" \
      ${hub.package}/bin/beszel-hub migrate up
    ${lib.optionalString systemsEnabled ''
      {
        echo "systems:"
        for host in ${lib.escapeShellArgs agents}; do
          printf '  - name: %s\n    host: %s.${tailnetDomain}\n    token: %s\n' \
            "$host" "$host" "$(cat "$CREDENTIALS_DIRECTORY/$host")"
        done
      } > beszel_data/config.yml.tmp
      mv beszel_data/config.yml.tmp beszel_data/config.yml
    ''}
  '';
in
{
  services.beszel.hub = {
    enable = true;
    # PodMaker's container already holds Beszel's default 8090.
    port = 8091;
    inherit dataDir;
    environment = {
      APP_URL = "https://beszel.${tailnetDomain}";
      # Single sign-on: Caddy puts Authelia's answer in this header and strips
      # any copy the client sent (see sso.nix). The hub listens on loopback
      # only, so the header is honoured from nothing but this host.
      TRUSTED_AUTH_HEADER = "Remote-Email";
      DISABLE_PASSWORD_AUTH = "true";
    };
  };

  # The module's DynamicUser adopts an existing user of this name, which keeps
  # the data directory outside its StateDirectory writable across restarts.
  users.users.beszel-hub = {
    isSystemUser = true;
    group = "beszel-hub";
  };
  users.groups.beszel-hub = { };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 beszel-hub beszel-hub -" ];

  # Both replace the module's defaults, which they restate.
  services.caddy = {
    logFormat = ''
      level ERROR
      ${withoutToken}
    '';
    virtualHosts."http://beszel.${tailnetDomain}".logFormat = ''
      output file ${config.services.caddy.logDir}/access-http:__beszel.${tailnetDomain}.log
      ${withoutToken}
    '';
  };

  systemd.services.beszel-hub = {
    after = [ "prostagma-app-storage.service" ];
    requires = [ "prostagma-app-storage.service" ];
    unitConfig.RequiresMountsFor = [ dataDir ];
    serviceConfig = {
      ExecStartPre = lib.mkBefore [ prepare ];
      LoadCredential = lib.mkIf systemsEnabled (
        map (host: "${host}:${config.dotfiles.fnox.secrets."BESZEL_TOKEN_${lib.toUpper host}".path}") agents
      );
    };
  };

  dotfiles.fnox.secrets = lib.mkIf systemsEnabled (
    lib.listToAttrs (
      map (host: {
        name = "BESZEL_TOKEN_${lib.toUpper host}";
        value = {
          path = "/run/secrets/beszel/${host}-token";
          requiredBy = [ "beszel-hub.service" ];
        };
      }) agents
    )
  );

  # Collectors beyond the shared module's, each with the least access that
  # works; docs/monitoring.md lists what is left off and why. The module adds
  # the agent to the docker group, and access to the Docker socket is
  # equivalent to root on this host. The TrueNAS mounts are left out of
  # EXTRA_FILESYSTEMS: they are hard NFS mounts, and the agent's statfs has no
  # timeout, so a TrueNAS outage would hang its collection.
  services.beszel.agent.environment = {
    SKIP_SYSTEMD = false;
    # Status comes over D-Bus; the journal is only for showing logs, and would
    # give the hub every service's log, Authelia's and the containers' included.
    SKIP_SYSTEMD_LOGS = true;
    EXTRA_FILESYSTEMS = "/srv/apps";
    # Reads sysfs only; intel_gpu_top would need CAP_PERFMON and the host's
    # user namespace.
    GPU_COLLECTOR = [ "intel_sysfs" ];
  };
}
