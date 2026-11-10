{ config, lib, ... }:

let
  inherit (import ../../lib/fleet.nix) tailnetDomain;
  hubKey = config.dotfiles.beszel.hubKey;
  hub = config.services.beszel.hub;
  host = config.networking.hostName;
in
{
  imports = [ ./secrets.nix ];

  options.dotfiles.beszel.hubKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "Public key of the Beszel hub on prostagma. The hub's systems and every agent stay off while this is null; see docs/monitoring.md.";
    default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1/IIfYiCiY3Rt53kiRdsmuJQ3ds+Vaavx8j1xeU/Ky";
  };

  config = lib.mkIf (hubKey != null) {
    services.beszel.agent = {
      enable = true;
      environment = {
        # The agent dials the hub over WebSocket, so with SSH off it listens on
        # nothing. It checks the hub's signature against KEY; the hub checks
        # the agent's token.
        KEY = hubKey;
        DISABLE_SSH = "true";
        # A host cannot reach a Tailscale Service it hosts itself.
        HUB_URL =
          if hub.enable then "http://127.0.0.1:${toString hub.port}" else "https://beszel.${tailnetDomain}";
        TOKEN_FILE = "/run/credentials/beszel-agent.service/token";
        # Service status adds a D-Bus policy and read access to the whole
        # journal, so only hosts that ask for it get it.
        SKIP_SYSTEMD = lib.mkDefault true;
      };
    };

    systemd.services.beszel-agent.serviceConfig = {
      LoadCredential = "token:${config.dotfiles.fnox.secrets."BESZEL_TOKEN_${lib.toUpper host}".path}";
      # The module drops the user namespace whenever service status is
      # skipped, which no collector here needs; only the ZFS tools fail inside
      # one. It also allows /dev/zfs but keeps PrivateDevices, which hides the
      # device, and without it the agent reports no pools.
      PrivateUsers = lib.mkForce (!config.boot.zfs.enabled);
      PrivateDevices = lib.mkIf config.boot.zfs.enabled (lib.mkForce false);
    };

    dotfiles.fnox.secrets."BESZEL_TOKEN_${lib.toUpper host}" = {
      path = "/run/secrets/beszel/${host}-token";
      requiredBy = [ "beszel-agent.service" ];
    };
  };
}
