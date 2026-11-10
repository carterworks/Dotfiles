{
  home.stateVersion = "26.11";
  home.sessionVariables.EZA_ICON_SPACING = "2";

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  programs.fish.enable = true;
  programs.zsh.enable = true;
  programs.atuin.enable = true;
  programs.starship.enable = true;
  programs.git.enable = true;

  programs.eza = {
    enable = true;
    icons = "auto";
    extraOptions = [
      "--classify=auto"
      "--group-directories-first"
    ];
  };
  programs.fzf = {
    enable = true;
    historyWidget.command = "";
  };
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };
  programs.yazi = {
    enable = true;
    shellWrapperName = "yy";
  };

  programs.helix = {
    enable = true;
    settings = {
      editor.whitespace.render = "all";
      editor.indent-guides.render = true;
      keys.normal = {
        C-s = ":w";
        C-x = ":q";
      };
    };
  };
  programs.zellij = {
    enable = true;
    settings = {
      default_shell = "fish";
      default_mode = "locked";
      show_startup_tips = false;
      show_release_notes = false;
      osc8_hyperlinks = true;
    };
  };
}
