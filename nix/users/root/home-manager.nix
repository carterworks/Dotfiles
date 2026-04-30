{
  config,
  currentSystemName,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  home = {
    username = "root";
    homeDirectory = "/root";
    stateVersion = "25.11";
    sessionVariables = {
      EZA_ICON_SPACING = "2";
    };
  };

  programs.home-manager.enable = true;
  programs.fish = {
    enable = true;
        functions.oc = {
      description = "Attach to local opencode server when available";
      body = ''
        if test (count $argv) -gt 0
            opencode $argv
        else if command -sq curl; and command curl --silent --output /dev/null --connect-timeout 0.2 --max-time 0.2 http://127.0.0.1:4096
            opencode attach http://localhost:4096 --dir .
        else
            opencode
        end
      '';
  };
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
