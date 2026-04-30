{ ... }:

{
  home = {
    username = "root";
    homeDirectory = "/root";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
  programs.fish.enable = true;
  programs.git.enable = true;
  programs.helix.enable = true;
}
