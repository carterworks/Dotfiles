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
  toolkit = import ./desktop-theme-toolkit.nix {
    inherit lib theme;
    name = cfg.name;
  };
  kdeScheme = pkgs.writeText "${cfg.name}.colors" toolkit.kde;
  telegramPalette = pkgs.writeText "colors.tdesktop-theme" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: color: "${key}: ${color};") {
        windowBg = colors.background;
        windowFg = colors.text;
        windowBgOver = colors.hover;
        windowBgRipple = colors.pressed;
        windowFgOver = colors.hoverText;
        windowSubTextFg = colors.muted;
        windowSubTextFgOver = colors.hoverText;
        windowBoldFg = colors.text;
        windowBoldFgOver = colors.hoverText;
        windowBgActive = colors.selection;
        windowFgActive = colors.text;
        windowActiveTextFg = colors.positive;
        activeButtonBgOver = colors.hover;
        activeButtonBgRipple = colors.pressed;
        activeButtonSecondaryFg = colors.text;
        activeLineFg = colors.focus;
        activeLineFgError = colors.negative;
        lightButtonBgOver = colors.hover;
        lightButtonBgRipple = colors.pressed;
        attentionButtonFg = colors.negative;
        attentionButtonFgOver = colors.negative;
        menuIconFg = colors.muted;
        menuIconFgOver = colors.hoverText;
        menuSubmenuArrowFg = colors.text;
        menuFgDisabled = colors.muted;
        menuSeparatorFg = colors.border;
        placeholderFgActive = colors.muted;
        inputBorderFg = colors.border;
        filterInputBorderFg = colors.focus;
        checkboxFg = colors.muted;
        sliderBgInactive = colors.border;
        tooltipBg = colors.surface;
        tooltipFg = colors.text;
        tooltipBorderFg = colors.border;
        titleBg = colors.background;
        titleFg = colors.muted;
        titleFgActive = colors.text;
        dialogsBg = colors.background;
        dialogsNameFg = colors.text;
        dialogsTextFg = colors.muted;
        dialogsBgOver = colors.hover;
        dialogsBgActive = colors.selection;
        dialogsNameFgActive = colors.text;
        dialogsTextFgActive = colors.text;
        dialogsUnreadBg = colors.positive;
        dialogsUnreadFg = colors.surface;
        historyTextInFg = colors.text;
        historyTextOutFg = colors.text;
        historyLinkInFg = colors.link;
        historyLinkOutFg = colors.link;
        msgInBg = colors.surface;
        msgOutBg = colors.selection;
        msgInBgSelected = colors.hover;
        msgOutBgSelected = colors.hover;
        msgInServiceFg = colors.positive;
        msgOutServiceFg = colors.positive;
        msgInDateFg = colors.muted;
        msgOutDateFg = colors.muted;
        historyComposeAreaBg = colors.background;
        historyComposeAreaFg = colors.text;
        historyComposeAreaFgService = colors.muted;
        historyComposeIconFg = colors.muted;
        historyComposeIconFgOver = colors.text;
      }
    )
  );
  telegramTheme =
    pkgs.runCommandLocal "${cfg.name}.tdesktop-theme"
      {
        nativeBuildInputs = [
          pkgs.zip
          pkgs.imagemagick
        ];
      }
      ''
        cp ${telegramPalette} colors.tdesktop-theme
        magick -size 64x64 'xc:${colors.background}' background.png
        zip -q "$out" colors.tdesktop-theme background.png
      '';
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
    gtk.gtk3.extraCss = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "@import 'colors.css';";
    gtk.gtk4.extraCss = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "@import 'colors.css';";
    gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = lib.mkForce (theme.appearance == "dark");
    gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = lib.mkForce (theme.appearance == "dark");
    programs.ghostty.settings = theme.ghostty // {
      window-theme = theme.appearance;
    };
    programs.helix.settings.theme = theme.apps.helix;
    programs.zellij.settings.theme = theme.apps.zellij;
    programs.zellij.settings.themes = lib.optionalAttrs (theme.apps ? zellijTheme) {
      ${theme.apps.zellij} = theme.apps.zellijTheme;
    };
    programs.delta.options.light = theme.appearance == "light";
    programs.btop = {
      enable = true;
      settings.color_theme = theme.apps.btop;
      themes = lib.optionalAttrs (theme.apps ? btopTheme) {
        ${theme.apps.btop} = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: color: "theme[${name}]=${builtins.toJSON color}") theme.apps.btopTheme
        );
      };
    };
    home.packages = [
      (pkgs.writeShellApplication {
        name = "desktop-theme-audit";
        text = ''
          exec ${pkgs.python3}/bin/python3 ${./audit-desktop-theme.py} ${
            pkgs.writeText "live-desktop-theme.json" (
              builtins.toJSON {
                files = lib.listToAttrs (
                  map
                    (file: {
                      name = "${config.xdg.configHome}/${file}";
                      value = config.xdg.configFile.${file}.source;
                    })
                    (
                      [
                        "opencode/cli.json"
                        "herdr/config.toml"
                        "helix/config.toml"
                        "zellij/config.kdl"
                        "zed/settings.json"
                        "zed/themes/desktop-theme.json"
                        "fish/config.fish"
                      ]
                      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                        "desktop-theme/zen.css"
                        "gtk-3.0/colors.css"
                        "gtk-4.0/colors.css"
                        "gtk-4.0/gtk.css"
                        "satty/overrides.css"
                      ]
                    )
                );
                kde = "${config.xdg.configHome}/kdeglobals";
                palette = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
                  builtins.removeAttrs toolkit.scheme [ "General" ]
                );
                vaults = cfg.obsidianVaults;
                appearance = {
                  cssTheme = theme.apps.obsidian.name;
                  theme = if theme.appearance == "light" then "moonstone" else "obsidian";
                };
              }
            )
          }
        '';
      })
    ];
    # Global values shadow old mutable universal colors without discarding them.
    programs.fish.interactiveShellInit = lib.mkAfter (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: value: "set -g ${key} ${value}") {
          fish_color_normal = hex colors.text;
          fish_color_command = hex colors.text;
          fish_color_param = hex colors.text;
          fish_color_quote = hex colors.positive;
          fish_color_redirection = hex colors.visited;
          fish_color_end = hex colors.visited;
          fish_color_error = hex colors.negative;
          fish_color_comment = hex colors.muted;
          fish_color_operator = hex colors.warning;
          fish_color_escape = hex colors.visited;
          fish_color_autosuggestion = hex colors.muted;
          fish_color_selection = "${hex colors.text} --background=${hex colors.selection}";
          fish_color_search_match = "${hex colors.text} --background=${hex colors.selection}";
          fish_color_valid_path = "--underline";
          fish_color_cancel = hex colors.negative;
          fish_color_match = "${hex colors.text} --background=${hex colors.selection}";
          fish_color_history_current = "--bold";
          fish_color_cwd = hex colors.positive;
          fish_color_cwd_root = hex colors.negative;
          fish_color_user = hex colors.text;
          fish_color_host = hex colors.text;
          fish_color_host_remote = hex colors.warning;
          fish_color_status = hex colors.negative;
          fish_pager_color_prefix = "${hex colors.text} --bold";
          fish_pager_color_completion = hex colors.text;
          fish_pager_color_description = hex colors.muted;
          fish_pager_color_progress = "${hex colors.text} --background=${hex colors.selection}";
          fish_pager_color_background = "--background=${hex colors.background}";
          fish_pager_color_selected_background = "--background=${hex colors.selection}";
          fish_pager_color_selected_prefix = hex colors.text;
          fish_pager_color_selected_completion = hex colors.text;
          fish_pager_color_selected_description = hex colors.text;
          fish_pager_color_secondary_background = "--background=${hex colors.background}";
          fish_pager_color_secondary_prefix = hex colors.text;
          fish_pager_color_secondary_completion = hex colors.text;
          fish_pager_color_secondary_description = hex colors.muted;
        }
      )
      # Refresh even in terminals inheriting an already-loaded HM environment.
      + "\nset -gx FZF_DEFAULT_OPTS ${lib.escapeShellArg config.home.sessionVariables.FZF_DEFAULT_OPTS}\n"
    );
    programs.fzf = {
      enableFishIntegration = false; # fzf-fish owns the bindings.
      defaultOptions = [
        "--cycle"
        "--layout=reverse"
        "--border"
        "--height=90%"
        "--preview-window=wrap"
        "--marker=*"
      ];
      colors = {
        bg = colors.background;
        "bg+" = colors.selection;
        fg = colors.text;
        "fg+" = colors.text;
        hl = colors.link;
        "hl+" = colors.link;
        info = colors.muted;
        prompt = colors.text;
        pointer = colors.positive;
        marker = colors.positive;
        border = colors.border;
        header = colors.muted;
      };
    };
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
      "desktop-theme/telegram/${cfg.name}.tdesktop-theme".source = telegramTheme;
      "desktop-theme/heroic/${cfg.name}.css".text = ''
        body.${cfg.name} {
          --background: ${colors.background};
          --background-darker: ${colors.background};
          --background-lighter: ${colors.surface};
          --background-secondary: ${colors.surface};
          --body-background: ${colors.background};
          --current-background: ${colors.background};
          --input-background: ${colors.surface};
          --modal-background: ${colors.surface};
          --modal-border: ${colors.border};
          --navbar-background: ${colors.background};
          --navbar-active-background: ${colors.selection};
          --navbar-active: ${colors.text};
          --navbar-inactive: ${colors.muted};
          --navbar-accent: ${colors.positive};
          --text-default: ${colors.text};
          --text-secondary: ${colors.muted};
          --text-tertiary: ${colors.text};
          --text-quartenary: ${colors.border};
          --text-hover: ${colors.hoverText};
          --text-title: ${colors.text};
          --text-gametitle: ${colors.text};
          --primary: ${colors.positive};
          --primary-hover: ${colors.focus};
          --accent: ${colors.positive};
          --accent-overlay: ${colors.focus};
          --primary-button: ${colors.positive};
          --secondary-button: ${colors.link};
          --secondary-button-overlay: ${colors.focus};
          --play-button: ${colors.positive};
          --install-button: ${colors.link};
          --link-highlight: ${colors.link};
          --divider: ${colors.border};
          --action-icon: ${colors.muted};
          --action-icon-hover: ${colors.text};
          --icons-background: ${colors.surface};
          --search-bar-background: ${colors.surface};
          --search-bar-border: ${colors.border};
          --success: ${colors.positive};
          --danger: ${colors.negative};
          --status-success: ${colors.positive};
          --status-warning: ${colors.warning};
          --status-danger: ${colors.negative};
          --osk-background: ${colors.background};
          --osk-button-background: ${colors.surface};
          --osk-button-border: ${colors.border};
        }
      '';
      "satty/overrides.css".text = ''
        .outer_box, .toolbar {
          background-color: ${colors.background};
          color: ${colors.text};
        }
        .inner_box { background-color: ${colors.surface}; }
        .toolbar button { color: ${colors.text}; }
        .toolbar button:hover { background-color: ${colors.hover}; color: ${colors.hoverText}; }
        .toolbar button:checked, button.editing { background-color: ${colors.selection}; color: ${colors.selectedText}; }
        .toolbar button:focus-visible { outline-color: ${colors.focus}; }
        .toast { background-color: ${colors.surface}; color: ${colors.text}; border: 1px solid ${colors.border}; }
      '';
      "gtk-3.0/colors.css" = {
        force = true;
        text = toolkit.gtk;
      };
      "gtk-4.0/colors.css" = {
        force = true;
        text = toolkit.gtk;
      };
      "gtk-3.0/gtk.css".force = true;
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
      "color-schemes/${cfg.name}.colors".source = kdeScheme;
      "vicinae/themes/${cfg.name}.toml" = {
        force = true;
        text = ''
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
    home.activation.desktopThemeKde = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${pkgs.python3}/bin/python3 ${./apply-kde-theme.py} \
          ${lib.escapeShellArg "${config.xdg.configHome}/kdeglobals"} ${kdeScheme} ${lib.escapeShellArg cfg.name} ${../../../kde/kdeglobals}
        run ${pkgs.dbus}/bin/dbus-send --session /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0
      ''
    );
  };
}
