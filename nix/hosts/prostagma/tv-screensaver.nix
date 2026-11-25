{
  fleet,
  inputs,
  pkgs,
  ...
}:

let
  deployKey = "/run/secrets/github/tv-screensaver-deploy-key";
  port = 8790;
in
{
  imports = [ inputs.tv-screensaver.nixosModules.default ];

  # Frames for the living room TV's screensaver app. Ungated on purpose: the
  # app cannot sign in, and it only ever sees rendered images, never the key.
  services.tv-screensaver = {
    enable = true;
    inherit port;
    # Read-only access to Immich's CLIP vectors and faces, to put similar photos together.
    database.enable = true;
    immich = {
      url = "http://127.0.0.1:2283";
      apiKeyFile = "/run/secrets/tv-screensaver/immich-api-key";
    };
    # Weather, forecast and sunrise/sunset for the overlay.
    homeAssistant = {
      url = "http://homeassistant:8123";
      tokenFile = "/run/secrets/tv-screensaver/hass-token";
    };
    # The admin page's Start, Next, Back and Stop go through this Home Assistant remote;
    # the admin login list itself lives in the private repository.
    settings.control.remoteEntity = "remote.living_room_tv";
    settings.sources = {
      # Worth Saving
      albums = [ "a0de98ad-36a8-4e7f-9ebc-a8cd6c27b0fa" ];
      # Arianne and Victoria
      people = [
        "8032d83a-4f2b-4456-a45a-b171db6bf00c"
        "26d56cea-1b3b-415e-97b7-8af5e25425e8"
      ];
    };
    # Fallback for when the TV's Tailscale is down: an exception to serving
    # apps only through Tailscale Serve, open to the TV's address alone.
    lan = {
      enable = true;
      address = fleet.lan.prostagma;
      allowFrom = [ "192.168.5.227" ];
    };
  };

  # The key lives in the project's own fnox store. builtins.path copies just
  # that file, so the unit changes only when it does.
  dotfiles.fnox.secrets.TV_SCREENSAVER_IMMICH_API_KEY = {
    path = "/run/secrets/tv-screensaver/immich-api-key";
    file = builtins.path {
      path = "${inputs.tv-screensaver}/fnox.toml";
      name = "tv-screensaver-fnox.toml";
    };
    requiredBy = [ "tv-screensaver.service" ];
  };

  dotfiles.fnox.secrets.TV_SCREENSAVER_HASS_TOKEN = {
    path = "/run/secrets/tv-screensaver/hass-token";
    file = builtins.path {
      path = "${inputs.tv-screensaver}/fnox.toml";
      name = "tv-screensaver-fnox.toml";
    };
    requiredBy = [ "tv-screensaver.service" ];
  };

  systemd.services.tailscale-services.script = pkgs.lib.mkAfter ''
    # Last for the same Service-approval reason as Backrest.
    "$tailscale" serve --service=svc:tv-screensaver --https=443 http://127.0.0.1:${toString port}
  '';

  # The tv-screensaver flake input is a private repository. The nightly
  # auto-upgrade evaluates as root, so root's SSH gets a read-only deploy key
  # for that one repository; ./install fetches with carter's own credentials.
  dotfiles.fnox.secrets.TV_SCREENSAVER_DEPLOY_KEY = {
    path = deployKey;
    requiredBy = [
      "multi-user.target"
      "nixos-upgrade.service"
    ];
  };

  programs.ssh = {
    knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    extraConfig = ''
      Match host github.com localuser root
        IdentityFile ${deployKey}
    '';
  };
}
