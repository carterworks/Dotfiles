{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    btop
    curl
    jq
    nfs-utils
    ripgrep
    wget
  ];
}
