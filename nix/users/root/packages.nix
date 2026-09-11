{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fd
    fnox
    jq
    nfs-utils
    nodejs_latest
    ripgrep
    wget
  ];
}
