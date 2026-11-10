{ lib, pkgs, ... }:

{
  imports = [ ./shell.nix ];

  home = {
    username = "root";
    homeDirectory = "/root";
  };

  programs.fish.interactiveShellInit = ''
    ${lib.getExe' pkgs.fnox "fnox"} activate fish | source
  '';

  programs.zellij = {
    attachExistingSession = true;
    enableFishIntegration = true;
    settings.theme = "solarized_light";
  };
}
