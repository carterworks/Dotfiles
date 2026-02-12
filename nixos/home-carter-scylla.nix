{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "carter";
  home.homeDirectory = "/home/carter";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
