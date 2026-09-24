{
  pkgs,
  lib,
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
        # Immich matches an OIDC login to an existing account by email, so this
        # has to be the address on the Immich account itself. It is also a real
        # inbox, which the filesystem notifier could reach if it were ever
        # pointed at SMTP.
        email: carter@carter.works
        groups:
          - admins
  '';

  # Digest of the Audiobookshelf client secret. The plaintext is in
  # ${secretsDir}/audiobookshelf_client_secret and is the value to configure on
  # the application side.
  audiobookshelfClientSecret = "$pbkdf2-sha512$310000$8OycXiZhi8uctR/XEvRd5A$lE.elcaNRZ7.bhELA8dcYlsvur.ZmAFnu8zTL6DlJVQxhn25hjqLGAmVUvAKkb9WQakxFiWNgl9q0mn2vlS6gQ";

  # Digest of the Immich client secret, same pattern. The plaintext is in
  # ${secretsDir}/immich_client_secret and is the value to paste into Immich's
  # own OAuth settings.
  immichClientSecret = "$pbkdf2-sha512$310000$vub0ivsDB5zuFb2XCW5YCA$M2lxXuPv4070S3/uDqNos5yLS8jvAlTy/p/PyGBj76N/kgHB6EvAeFeLrXwHHk4ljKeu01VelJoU4yCs.XnNpA";

  # Applications with no OIDC support, gated at the reverse proxy instead.
  #
  # Every listener named here is published on 127.0.0.1 only and is not allowed
  # through the firewall, so Tailscale Serve is the sole ingress and the gate
  # cannot be bypassed on another interface. Each application keeps its own
  # login as well: Servarr's `External` authentication method is a plain auth
  # disable that reads no proxy header, so an Authelia identity cannot be
  # mapped onto an application user. The gate protects the network edge, and
  # the application login remains as the second layer.
  gatedApps = [
    {
      name = "sonarr";
      port = 30113;
    }
    {
      name = "radarr";
      port = 30025;
    }
    {
      name = "prowlarr";
      port = 30050;
    }
    {
      name = "qbittorrent";
      port = 38080;
    }

    # Bazarr has no proxy-auth mode and its UI fetches /api/* over XHR, where
    # the gate's redirect would replace JSON and break the interface, so only
    # its UI is gated. Its API keeps relying on Bazarr's own API key.
    {
      name = "bazarr";
      port = 6767;
      apiBypass = true;
    }

    # Backrest has no OIDC and no header auth, and its own authentication is
    # disabled in its config, so this gate is its only lock.
    {
      name = "backrest";
      port = 9898;
    }
  ];
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

      # One cookie for the whole tailnet domain. Authelia refuses any host
      # without a matching entry, and the forward-auth gate additionally needs
      # the browser to *send* the session cookie to each gated application,
      # which only happens if the cookie covers that application's hostname.
      # A parent domain covers the portal, the retired host-and-port URL and
      # every application in one entry, and it is a suffix of authelia_url,
      # which is what Authelia requires. Changing this invalidates existing
      # sessions, so everyone logs in once more.
      session.cookies = [
        {
          domain = tailnetDomain;
          authelia_url = authServiceUrl;
        }
      ];

      storage.local.path = "${stateDir}/db.sqlite3";

      # Authelia refuses to start without a notifier. The filesystem one
      # keeps this to a single process: nothing is sent anywhere, messages
      # such as a password reset request are simply written to a file.
      notifier.filesystem.filename = "${stateDir}/notification.txt";

      access_control = {
        # Authelia rejects "deny" while the rule list is empty, so the default
        # states the policy that applies to any host without a rule of its own.
        default_policy = "one_factor";

        # The gate asks Authelia about the *original* URL, so a rule has to
        # match the application hostname rather than the portal's own.
        rules = map (app: {
          domain = "${app.name}.${tailnetDomain}";
          policy = "one_factor";
        }) gatedApps;
      };

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

        {
          client_id = "immich";
          client_name = "Immich";
          client_secret = immichClientSecret;
          public = false;
          authorization_policy = "one_factor";

          # Immich matches an OIDC login to an existing account by email, which
          # is why the user above carries the Immich account's address.
          redirect_uris = [
            "https://immich.${tailnetDomain}/auth/login"
            "https://immich.${tailnetDomain}/user-settings"

            # Immich forwards this to app.immich:///oauth-callback, so the
            # mobile app works without registering a custom scheme here.
            "https://immich.${tailnetDomain}/api/oauth/mobile-redirect"
          ];

          scopes = [
            "openid"
            "profile"
            "email"
          ];

          # Immich sends its credentials in the request body by default, while
          # Authelia expects them in the Authorization header. Without this the
          # token exchange fails in a way that looks like a wrong secret.
          token_endpoint_auth_method = "client_secret_post";

          consent_mode = "implicit";
        }
      ];
    };
  };

  # The gate itself: one Caddy site per application, on the plain-HTTP
  # listener the host already runs for the service directory. Serve preserves
  # the original Host header, so Caddy selects the site by hostname exactly as
  # it does for the directory.
  services.caddy.virtualHosts = builtins.listToAttrs (
    map (app: {
      name = "http://${app.name}.${tailnetDomain}";
      value.extraConfig = ''
        # Serve connects to Caddy over loopback, and the directory sites are
        # bound to loopback explicitly. A site without a matching bind lands in
        # a separate wildcard listener, and the kernel prefers the specific
        # bind, so Serve's connection would be answered by the directory server
        # and never reach this site.
        bind 127.0.0.1 ::1

        ${lib.optionalString (app.apiBypass or false) "@notapi not path /api/*\n"}
        forward_auth ${lib.optionalString (app.apiBypass or false) "@notapi "}127.0.0.1:9091 {
          uri /api/authz/forward-auth
          copy_headers Remote-User Remote-Groups Remote-Email Remote-Name

          # Serve terminates TLS, so the browser is on https while this hop is
          # plain http. Authelia derives the target URL from the request scheme
          # and refuses anything that is not https or wss, so state the
          # external scheme explicitly or every request fails with "has an
          # insecure scheme 'http'".
          header_up X-Original-URL "https://{host}{uri}"
          header_up X-Forwarded-Proto https
        }
        reverse_proxy 127.0.0.1:${toString app.port}
      '';
    }) gatedApps
  );

  # Containers reach the portal through the tailnet address, which means the
  # port has to be accepted from the docker bridge as well as from the tailnet.
  # Serve only ever binds the tailnet address, so nothing on the LAN or on the
  # public internet is listening on this port.
  networking.firewall.allowedTCPPorts = [ authPortalPort ];
}
