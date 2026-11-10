{ modulesPath, pkgs, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  # the proxmox-lxc module forces networking.hostName to "" by default
  proxmoxLXC.manageHostName = true;

  home-manager.users.root = ../home/root.nix;

  environment.systemPackages = with pkgs; [
    nfs-utils
    nodejs_latest
  ];
}
