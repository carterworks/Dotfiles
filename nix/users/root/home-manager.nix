{
  config,
  currentSystemName,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  opencodePort = 4096;
in

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
  programs.fish.enable = true;
  programs.atuin.enable = true;

  systemd.user.services.opencode =
    lib.mkIf (pkgs.stdenv.isLinux && currentSystemName == "prostagma")
      {
        Unit.Description = "opencode server";
        Service = {
          ExecStart = "${opencode}/bin/opencode serve --hostname 0.0.0.0 --port ${toString opencodePort}";
          WorkingDirectory = "%h";
          Environment = [
            "HOME=%h"
            "PATH=%h/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

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
