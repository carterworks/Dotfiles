{
  inputs,
  pkgs,
  self,
  ...
}:

let
  fff-mcp = self.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in

{
  environment.systemPackages = with pkgs; [
    btop
    curl
    fff-mcp
    jq
    nfs-utils
    opencode
    ripgrep
    wget
  ];
}
