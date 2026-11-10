{ modulesPath, pkgs, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  # the proxmox-lxc module forces networking.hostName to "" by default
  proxmoxLXC.manageHostName = true;

  home-manager.users.root = ../home/root.nix;

  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fd
    fff-mcp
    fnox
    jq
    nfs-utils
    nodejs_latest
    ripgrep
    wakeonlan
    wget
  ];
}
