{
  pkgs,
  self,
  ...
}:

let
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
in

{
  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fff-mcp
    fnox
    jq
    nfs-utils
    ripgrep
    wget
  ];
}
