{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  # the proxmox-lxc module forces networking.hostName to "" by default
  proxmoxLXC.manageHostName = true;

  home-manager.users.root = ../home/root.nix;

  environment.systemPackages = with pkgs; [
    nfs-utils
    nodejs_latest
  ];

  # Only the private cache holds what CI built that public caches lack; without
  # it a server would build those paths itself, which on eltoro the egress fence
  # also blocks. `release` advances only after the cache has the commit.
  system.autoUpgrade = lib.mkIf (config.dotfiles.binaryCache.publicKey != null) {
    enable = true;
    flake = "github:carterworks/dotfiles/release#${config.networking.hostName}";
    # --upgrade updates channels, which a flake host does not use.
    upgrade = false;
    # After nix-gc (03:15) and the profile prune (02:45) have finished.
    dates = "04:30";
    randomizedDelaySec = "30min";
  };
}
