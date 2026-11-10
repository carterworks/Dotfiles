{
  pkgs,
  ...
}:

{
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
