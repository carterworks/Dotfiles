{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.desktopTheme;
  theme = import (./themes + "/${cfg.name}.nix");
  inherit (theme) colors;
  hex = color: lib.removePrefix "#" color;
in
{
  options.dotfiles.desktopTheme = {
    name = lib.mkOption {
      type = lib.types.enum (
        map (file: lib.removeSuffix ".nix" file) (
          lib.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir ./themes))
        )
      );
      default = "everforest-light-medium";
      description = "Theme shared by the desktop shell, terminal, and browser.";
    };
    zenProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Existing Zen profile path, relative to the home directory. Does not change profiles.ini.";
    };
  };

  config = {
    programs.ghostty.settings = theme.ghostty // {
      window-theme = theme.appearance;
    };

    xdg.configFile = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      "quickshell/DesktopColors.qml".text = ''
        pragma Singleton
        import QtQuick

        QtObject {
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: color: "    readonly property color ${name}: \"${color}\"") colors
        )}
        }
      '';
      "hypr/desktop-colors.lua".text = ''
        return {
            active_border = "rgba(${hex colors.accent}ff)",
            inactive_border = "rgba(${hex colors.border}ff)",
        }
      '';
      "desktop-theme/zen.css".text = ''
        :root {
          color-scheme: ${theme.appearance} !important;
          --zen-primary-color: ${colors.accent} !important;
          --zen-main-browser-background: ${colors.background} !important;
          --zen-main-browser-background-toolbar: ${colors.background} !important;
          --zen-colors-primary: ${colors.surface} !important;
          --zen-colors-secondary: ${colors.hover} !important;
          --zen-colors-tertiary: ${colors.background} !important;
          --zen-colors-border: ${colors.border} !important;
          --zen-colors-input-bg: ${colors.surface} !important;
          --zen-dialog-background: ${colors.surface} !important;
          --zen-colors-primary-foreground: ${colors.text} !important;
          --zen-colors-hover-bg: ${colors.hover} !important;
          --zen-urlbar-background: ${colors.surface} !important;
          --toolbox-textcolor: ${colors.text} !important;
          --toolbar-bgcolor: ${colors.background} !important;
          --toolbar-color: ${colors.text} !important;
          --toolbar-field-background-color: ${colors.surface} !important;
          --toolbar-field-color: ${colors.text} !important;
          --toolbar-field-border-color: ${colors.border} !important;
          --toolbar-field-focus-border-color: ${colors.accent} !important;
          --lwt-text-color: ${colors.text} !important;
          --lwt-sidebar-background-color: ${colors.background} !important;
          --lwt-sidebar-text-color: ${colors.text} !important;
          --arrowpanel-background: ${colors.surface} !important;
          --arrowpanel-color: ${colors.text} !important;
          --arrowpanel-border-color: ${colors.border} !important;
          --tab-selected-bgcolor: ${colors.selection} !important;
          --tab-selected-textcolor: ${colors.text} !important;
          --urlbarView-highlight-background: ${colors.selection} !important;
          --urlbarView-highlight-color: ${colors.text} !important;
        }

        .zen-browser-generic-background {
          --zen-main-browser-background: ${colors.background} !important;
          --zen-main-browser-background-toolbar: ${colors.background} !important;
          --zen-main-browser-background-old: ${colors.background} !important;
          --zen-main-browser-background-toolbar-old: ${colors.background} !important;
          --zen-background-opacity: 1 !important;
        }

        .zen-browser-generic-background .zen-browser-grain {
          display: none !important;
        }
      '';
    };

    home.file = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && cfg.zenProfile != null) {
      "${cfg.zenProfile}/chrome/userChrome.css".text = ''
        @import url("file://${config.xdg.configHome}/desktop-theme/zen.css");
      '';
      "${cfg.zenProfile}/user.js".text = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("browser.theme.content-theme", 1);
        user_pref("browser.theme.toolbar-theme", 1);
      '';
    };
  };
}
