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
  cliSettings = builtins.fromJSON (builtins.readFile ../../../opencode/cli.json);
  herdrColors = theme.apps.herdrColors // {
    accent = colors.accent;
    panel_bg = colors.background;
    sidebar_bg = colors.background;
    active_row_bg = colors.selection;
    selection_bg = colors.hover;
    surface0 = colors.surface;
    surface1 = colors.hover;
    surface_dim = colors.border;
    overlay0 = colors.border;
    overlay1 = colors.muted;
    text = colors.text;
    subtext0 = colors.muted;
  };
  obsidianSource = pkgs.fetchFromGitHub theme.apps.obsidian.source;
  obsidianTheme = pkgs.runCommandLocal "obsidian-${cfg.name}" { } ''
    mkdir -p "$out"
    cp ${obsidianSource}/manifest.json ${obsidianSource}/theme.css "$out/"
    ${lib.concatMapStringsSep "\n" (replacement: ''
      substituteInPlace "$out/theme.css" --replace-fail \
        ${lib.escapeShellArg replacement.from} ${lib.escapeShellArg replacement.to}
    '') (theme.apps.obsidian.cssReplacements or [ ])}
  '';
  obsidianSettings = pkgs.writeText "obsidian-theme-settings.json" (
    builtins.toJSON {
      vaults = map (vault: "${config.home.homeDirectory}/${vault}") cfg.obsidianVaults;
      appearance = {
        cssTheme = theme.apps.obsidian.name;
        theme = if theme.appearance == "light" then "moonstone" else "obsidian";
      };
    }
  );
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
      description = "Theme shared by the desktop shell, terminal, browser, and editors.";
    };
    zenProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Existing Zen profile path, relative to the home directory. Does not change profiles.ini.";
    };
    obsidianVaults = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Obsidian vault paths relative to the home directory. Only appearance and theme files are managed.";
    };
  };

  config = {
    programs.ghostty.settings = theme.ghostty // {
      window-theme = theme.appearance;
    };
    programs.helix.settings.theme = theme.apps.helix;
    programs.zellij.settings.theme = theme.apps.zellij;
    programs.delta.options.light = theme.appearance == "light";
    programs.zed-editor.userSettings.theme = {
      mode = theme.appearance;
      light = theme.apps.zed.name;
      dark = theme.apps.zed.name;
    };

    xdg.configFile = {
      "opencode/cli.json" = {
        force = true;
        text = builtins.toJSON (
          cliSettings
          // {
            theme = {
              name = theme.apps.opencode;
              mode = theme.appearance;
            };
          }
        );
      };
      "herdr/config.toml" = {
        force = true;
        text = builtins.readFile ../../../herdr/config.toml + ''

          [theme]
          name = ${builtins.toJSON theme.apps.herdr}
          auto_switch = false

          [theme.custom]
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: color: "${name} = ${builtins.toJSON color}") herdrColors
          )}
        '';
      };
      "zed/themes/desktop-theme.json".source = pkgs.fetchurl theme.apps.zed.source;
      "desktop-theme/obsidian.json".source = obsidianSettings;
      "desktop-theme/obsidian".source = obsidianTheme;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      "vicinae/desktop-theme.json".text = builtins.toJSON {
        theme = {
          light.name = cfg.name;
          dark.name = cfg.name;
        };
      };
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

    xdg.dataFile = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      "vicinae/themes/${cfg.name}.toml".text = ''
        [meta]
        version = 1
        name = "${cfg.name}"
        description = "Shared desktop palette"
        variant = "${theme.appearance}"
        inherits = "vicinae-${theme.appearance}"

        [colors.core]
        background = "${colors.background}"
        foreground = "${colors.text}"
        secondary_background = "${colors.surface}"
        border = "${colors.border}"
        accent = "${colors.accent}"
        accent_foreground = "${colors.background}"

        [colors.accents]
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: color: "${name} = ${builtins.toJSON color}") {
            inherit (theme.apps.herdrColors)
              blue
              green
              red
              yellow
              ;
            magenta = theme.apps.herdrColors.mauve;
            purple = theme.apps.herdrColors.mauve;
            cyan = theme.apps.herdrColors.teal;
            orange = theme.apps.herdrColors.peach;
          }
        )}

        [colors.text]
        muted = "${colors.muted}"
        placeholder = "${colors.muted}"
        selection = { background = "${colors.selection}", foreground = "${colors.text}" }

        [colors.list.item.hover]
        foreground = "${colors.text}"
        secondary_foreground = "${colors.text}"

        [colors.list.item.selection]
        background = "${colors.selection}"
        foreground = "${colors.text}"
        secondary_background = "${colors.selection}"
        secondary_foreground = "${colors.text}"
      '';
    };

    home.file =
      lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && cfg.zenProfile != null) {
        "${cfg.zenProfile}/chrome/userChrome.css".text = ''
          @import url("file://${config.xdg.configHome}/desktop-theme/zen.css");
        '';
        "${cfg.zenProfile}/user.js".text = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          user_pref("browser.theme.content-theme", 1);
          user_pref("browser.theme.toolbar-theme", 1);
        '';
      }
      // lib.listToAttrs (
        map (vault: {
          name = "${vault}/.obsidian/themes/${theme.apps.obsidian.name}";
          value.source = obsidianTheme;
        }) cfg.obsidianVaults
      );

    home.activation.desktopThemeObsidian = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${pkgs.python3}/bin/python3 ${./apply-obsidian-theme.py} ${obsidianSettings}
    '';
  };
}
