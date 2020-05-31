{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "carter";
  home.homeDirectory = "/home/carter";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.09";

  nixpkgs.config.allowUnfree = true;

  # Enable github.com/target/lorri, for managing build environments
  services.lorri.enable = true;

  programs.lsd = {
    enable = true;
    enableAliases = true;
  };

  home.packages = [
    pkgs.htop
    pkgs.direnv
    pkgs.neovim
    pkgs.bat
    pkgs.fd
    pkgs.ripgrep
    pkgs.niv
    pkgs.openssh
    pkgs.git
    pkgs.python3
    pkgs.tmux
    pkgs.starship
  ];
}
