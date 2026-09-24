{
  pkgs,
  ...
}:

# Unified authentication for the services on this host.
#
# Authelia is the only service this adds. It serves two roles from one process:
# an OpenID Connect provider that applications with native OIDC support use
# directly, and a forward-auth gate for applications that have none. Storage is
# SQLite, sessions are in memory, users come from a file: no Redis, no database
# server, no worker process.
#
# This is deliberately additive. Every application keeps its own accounts and
# keeps working if this service is stopped, so the host cannot be locked out by
# a mistake here.
let
  tailnetDomain = "dropbear-tortoise.ts.net";

  # The portal doubles as the OIDC issuer, so it needs a URL that is valid
  # HTTPS for the browser and for the applications making server-side token
  # calls from inside their containers. Tailscale Serve terminates TLS with the
  # tailnet certificate and proxies to the loopback listener below. Port 8443
  # is used because the default 443 route already belongs to Caddy.
  authPortalPort = 8443;
  authPortalUrl = "https://prostagma.${tailnetDomain}:${toString authPortalPort}";

  # The portal also has its own Tailscale Service, and this is the URL
  # clients should use: a MagicDNS name with no port is a valid OpenID
  # Connect issuer, whereas host:port is awkward to register everywhere.
  authServiceUrl = "https://authelia.${tailnetDomain}";

  secretsDir = "/var/lib/secrets/authelia";

  # State directory that systemd creates for the service (0700, owned by it).
  stateDir = "/var/lib/authelia-main";

  # Secrets are root-only files outside the Nix store, handed to the service as
  # systemd credentials. This repository is public, so nothing secret may be
  # referenced from here.
  #
  # Users live in the store so that the account list stays declarative. What
  # ends up in the repository is an argon2id digest of a 24-character random
  # password, which is not a practical disclosure. To set a new password:
  #
  #   authelia crypto hash generate argon2 --password '<new password>'
  #
  # and replace the digest below.
  usersFile = pkgs.writeText "authelia-users.yml" ''
    users:
      carter:
        displayname: Carter McBride
        password: "$argon2id$v=19$m=65536,t=3,p=4$8628xF5AF1yqFebLh5VQzA$qtAtz8zzEkgI/ofo/M9XTw2/YM7g/XwUr/L8VuL8/wI"
        email: 18412686+carterworks@users.noreply.github.com
        groups:
          - admins
  '';

  # Digest of the Audiobookshelf client secret. The plaintext is in
  # ${secretsDir}/audiobookshelf_client_secret and is the value to configure on
  # the application side.
  audiobookshelfClientSecret = "$pbkdf2-sha512$310000$8OycXiZhi8uctR/XEvRd5A$lE.elcaNRZ7.bhELA8dcYlsvur.ZmAFnu8zTL6DlJVQxhn25hjqLGAmVUvAKkb9WQakxFiWNgl9q0mn2vlS6gQ";
in
{
  services.authelia.instances.main = {
    enable = true;

    secrets = {
      jwtSecretFile = "${secretsDir}/jwt_secret";
      sessionSecretFile = "${secretsDir}/session_secret";
      storageEncryptionKeyFile = "${secretsDir}/storage_encryption_key";
      oidcHmacSecretFile = "${secretsDir}/oidc_hmac_secret";
      oidcIssuerPrivateKeyFile = "${secretsDir}/oidc_issuer_private.pem";
    };

    settings = {
      theme = "auto";
      log.level = "info";

      # Reachable only through Tailscale Serve, so the listener stays on
      # loopback and cannot be bypassed from the LAN or the tailnet.
      server.address = "tcp://127.0.0.1:9091/";

      authentication_backend.file.path = usersFile;

      # Authelia refuses any host without a matching entry here, so both the
      # Service name and the old host-and-port URL are declared. The second
      # entry is removed once nothing points at the host-and-port URL.
      session.cookies = [
        {
          domain = "authelia.${tailnetDomain}";
          authelia_url = authServiceUrl;
        }
        {
          domain = "prostagma.${tailnetDomain}";
          authelia_url = authPortalUrl;
        }
      ];

      storage.local.path = "${stateDir}/db.sqlite3";

      # Authelia refuses to start without a notifier. The filesystem one
      # keeps this to a single process: nothing is sent anywhere, messages
      # such as a password reset request are simply written to a file.
      notifier.filesystem.filename = "${stateDir}/notification.txt";

      # Nothing is gated yet: rules are added one application at a time as
      # each is migrated, and they set their own policy. Authelia rejects
      # "deny" here while the rule list is empty.
      access_control.default_policy = "one_factor";

      identity_providers.oidc.clients = [
        {
          client_id = "audiobookshelf";
          client_name = "Audiobookshelf";
          client_secret = audiobookshelfClientSecret;
          public = false;

          # The application keeps its local login, so password-only is enough
          # to start with. Raise this to two_factor once a passkey or TOTP
          # has been registered, or the login will demand 2FA nobody can supply.
          authorization_policy = "one_factor";

          # Audiobookshelf matches an OIDC login to an existing account by
          # preferred_username, which is the Authelia username, so this maps
          # onto the existing account instead of creating a second one.
          redirect_uris = [
            "https://audiobookshelf.${tailnetDomain}/auth/openid/callback"
            "https://audiobookshelf.${tailnetDomain}/auth/openid/mobile-redirect"
          ];

          scopes = [
            "openid"
            "profile"
            "email"
          ];

          # Authelia 4.39.22 cannot save the consent session for this flow:
          # the client gets "Error in callback" and the server logs
          # "error updating oauth2 consent session ... no rows affected".
          # Implicit consent skips the consent mechanism entirely, which is
          # acceptable for a confidential, single-user client; Authelia only
          # discourages it for public clients whose secrets are exposed.
          consent_mode = "implicit";
        }
      ];
    };
  };

  # Containers reach the portal through the tailnet address, which means the
  # port has to be accepted from the docker bridge as well as from the tailnet.
  # Serve only ever binds the tailnet address, so nothing on the LAN or on the
  # public internet is listening on this port.
  networking.firewall.allowedTCPPorts = [ authPortalPort ];
}
