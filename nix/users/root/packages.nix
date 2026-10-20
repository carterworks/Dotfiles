{
  pkgs,
  self,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fd
    self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp
    fnox
    jq
    nfs-utils
    nodejs_latest
    ripgrep
    wget
  ];
}
