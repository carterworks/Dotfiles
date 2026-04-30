{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    curl
    git
    helix
    jq
    nfs-utils
    ripgrep
    wget
  ];
}
