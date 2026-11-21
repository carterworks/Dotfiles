{ inputs, pkgs, ... }:

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
    immich = {
      url = "http://127.0.0.1:2283";
      apiKeyFile = "/run/secrets/tv-screensaver/immich-api-key";
    };
    settings.sources.albums = [
      "3af0b920-fe46-4fb1-ad04-363fc29fc306"
      "2d6014f4-25d7-4606-8895-49ad1c82c3a5"
      "0e16b2c8-075b-4cc0-93ff-cb529c9d975a"
    ];
    # Fallback for when the TV's Tailscale is down: an exception to serving
    # apps only through Tailscale Serve, open to the TV's address alone.
    lan = {
      enable = true;
      address = "192.168.4.29";
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
