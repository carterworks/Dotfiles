{ ... }:

let
  deployKey = "/run/secrets/github/tv-screensaver-deploy-key";
in
{
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
