{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fnox
    jq
    nfs-utils
    ripgrep
    wget
  ];
}
