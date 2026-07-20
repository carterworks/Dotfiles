{
  lib,
  pkgs,
  ...
}:

{
  home = {
    username = "root";
    homeDirectory = "/root";
    stateVersion = "26.11";
    sessionVariables = {
      EZA_ICON_SPACING = "2";
    };
  };

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      ${lib.getExe' pkgs.fnox "fnox"} activate fish | source
    '';
  };
  programs.zsh.enable = true;
  programs.atuin.enable = true;

  programs.eza = {
    enable = true;
    icons = "auto";
    extraOptions = [
      "--classify=auto"
      "--group-directories-first"
    ];
  };
  programs.git.enable = true;
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
    attachExistingSession = true;
    enableFishIntegration = true;
    settings = {
      default_shell = "fish";
      theme = "solarized_light";
      default_mode = "locked";
      show_startup_tips = false;
      show_release_notes = false;
      osc8_hyperlinks = true;
    };
  };
  programs.starship.enable = true;
  programs.fzf.enable = true;
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
}
