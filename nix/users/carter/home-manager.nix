{
  pkgs,
  lib,
  ...
}:

{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  xdg.configFile."git/aliases".source = ../../git/aliases;

  wayland.windowManager.hyprland = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    package = null;
    portalPackage = null;
    systemd.variables = [ "--all" ];
    extraConfig = builtins.readFile ../../hypr/hyprland.conf;
  };

  programs.zed-editor = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    userSettings = {
      agent_servers = {
        cursor = {
          type = "registry";
        };
        opencode = {
          type = "registry";
        };
      };
      agent = {
        play_sound_when_agent_done = true;
        model_parameters = [ ];
      };
      autosave = "on_focus_change";
      auto_signature_help = true;
      buffer_font_features = {
        calt = true;
      };
      buffer_font_family = "Iosevka";
      buffer_font_fallbacks = [
        "Iosevka Nerd Font"
        ".ZedMono"
      ];
      buffer_font_size = 16;
      show_edit_predictions = true;
      minimap = {
        show = "auto";
      };
      tabs = {
        file_icons = true;
        git_status = true;
      };
      format_on_save = "on";
      indent_guides = {
        active_line_width = 6;
        coloring = "indent_aware";
        line_width = 3;
      };
      git = {
        inline_blame = {
          delay_ms = 300;
          min_column = 100;
        };
      };
      icon_theme = {
        dark = "Colored Zed Icons Theme Dark";
        light = "Colored Zed Icons Theme Light";
      };
      linked_edits = true;
      show_whitespaces = "all";
      tab_size = 2;
      terminal = {
        font_family = "Iosevka Term";
        font_size = 16;
        shell = {
          program = "fish";
        };
      };
      theme = {
        mode = "light";
        dark = "Everforest Dark Hard (regular)";
        light = "Base16 selenized-light";
      };
      title_bar = {
        show_branch_icon = true;
        show_menus = true;
      };
      ui_font_family = ".SystemUIFont";
      languages = {
        Nix = {
          language_servers = [
            "nixd"
            "!nil"
          ];
        };
      };
    };
  };

  services.mako = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    settings = {
      font = "Inter 10";
      background-color = "#fbf3db";
      text-color = "#53676d";
      border-color = "#d5cdb6";
      border-size = 2;
      border-radius = 10;
      padding = "12";
      margin = "10";
      outer-margin = "10";
      width = 300;
      height = 100;
      anchor = "top-right";
      icons = true;
      icon-path = "/usr/share/icons/hicolor";
      max-icon-size = 32;
      default-timeout = 5000;
      ignore-timeout = false;
      history = true;
      layer = "overlay";
      "urgency=low" = {
        border-color = "#909995";
      };
      "urgency=normal" = {
        border-color = "#0072d4";
      };
      "urgency=critical" = {
        border-color = "#d2212d";
        background-color = "#ece3cc";
      };
    };
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "theme";
      editor.whitespace.render = "all";
      editor.indent-guides.render = true;
      keys.normal = {
        C-s = ":w";
        C-x = ":q";
      };
    };
    languages = {
      language = [
        {
          name = "toon";
          scope = "text.toon";
          file-types = [ "toon" ];
          grammar = "yaml";
          soft-wrap.enable = true;
        }
        {
          name = "text";
          scope = "text.plain";
          file-types = [ "txt" ];
          soft-wrap.enable = true;
        }
        {
          name = "markdown";
          scope = "source.md";
          file-types = [
            "md"
            "markdown"
          ];
          soft-wrap.enable = true;
        }
      ];
    };
    themes.theme = {
      "ui.menu" = {
        fg = "light-gray";
        bg = "gray";
      };
      "ui.menu.selected" = {
        modifiers = [ "reversed" ];
      };
      "ui.linenr" = {
        fg = "light-gray";
        bg = "black";
      };
      "ui.popup" = {
        bg = "black";
      };
      "ui.window" = {
        bg = "black";
      };
      "ui.linenr.selected" = {
        fg = "white";
        bg = "black";
        modifiers = [ "bold" ];
      };
      "ui.selection" = {
        fg = "gray";
        modifiers = [ "reversed" ];
      };
      comment = {
        fg = "light-gray";
        modifiers = [ "italic" ];
      };
      "ui.statusline" = {
        fg = "white";
        bg = "black";
      };
      "ui.statusline.inactive" = {
        fg = "gray";
        bg = "black";
      };
      "ui.help" = {
        fg = "white";
        bg = "black";
      };
      "ui.cursor" = {
        fg = "light-gray";
        modifiers = [ "reversed" ];
      };
      "ui.cursor.primary" = {
        fg = "light-gray";
        modifiers = [ "reversed" ];
      };
      "ui.virtual.whitespace" = "light-gray";
      "ui.virtual.jump-label" = {
        fg = "blue";
        modifiers = [
          "bold"
          "underlined"
        ];
      };
      "ui.virtual.ruler" = {
        bg = "black";
      };
      variable = "light-red";
      "constant.numeric" = "yellow";
      constant = "yellow";
      attribute = "yellow";
      type = "light-yellow";
      "ui.cursor.match" = {
        fg = "light-yellow";
        modifiers = [ "underlined" ];
      };
      string = "light-green";
      "variable.other.member" = "light-green";
      "constant.character.escape" = "light-cyan";
      function = "light-blue";
      constructor = "light-blue";
      special = "light-blue";
      keyword = "light-magenta";
      label = "light-magenta";
      namespace = "light-magenta";
      "markup.heading" = "light-blue";
      "markup.list" = "light-red";
      "markup.bold" = {
        fg = "light-yellow";
        modifiers = [ "bold" ];
      };
      "markup.italic" = {
        fg = "light-magenta";
        modifiers = [ "italic" ];
      };
      "markup.strikethrough" = {
        modifiers = [ "crossed_out" ];
      };
      "markup.link.url" = {
        fg = "yellow";
        modifiers = [ "underlined" ];
      };
      "markup.link.text" = "light-red";
      "markup.quote" = "light-cyan";
      "markup.raw" = "light-green";
      "diff.plus" = "light-green";
      "diff.delta" = "yellow";
      "diff.minus" = "light-red";
      diagnostic = {
        modifiers = [ "underlined" ];
      };
      "ui.gutter" = {
        bg = "black";
      };
      info = "light-blue";
      hint = "gray";
      debug = "gray";
      warning = "yellow";
      error = "light-red";
    };
  };

  programs.ghostty = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    enableFishIntegration = true;
    settings = {
      config-file = [
        "?~/.local/share/omarchy/config/ghostty/config"
        "?./theme"
      ];
      window-theme = "auto";
      font-family = "Iosevka Term";
      font-size = 13;
      command = "sh -c 'command -v fish >/dev/null 2>&1 && exec fish || test -x /run/current-system/sw/bin/fish && exec /run/current-system/sw/bin/fish || exec \"$SHELL\"'";
      shell-integration-features = "ssh-terminfo";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      scan_timeout = 10;
      aws.disabled = true;
      rlang.disabled = true;
      custom.jj = {
        description = "The current jj status";
        when = "jj --ignore-working-copy root";
        symbol = "🥋 ";
        command = ''
          jj log --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '
            separate(" ",
              change_id.shortest(4),
              bookmarks,
              "|",
              concat(
                if(conflict, "💥"),
                if(divergent, "🚧"),
                if(hidden, "👻"),
                if(immutable, "🔒"),
              ),
              raw_escape_sequence("\x1b[1;32m") ++ if(empty, "(empty)"),
              raw_escape_sequence("\x1b[1;32m") ++ coalesce(
                truncate_end(29, description.first_line(), "…"),
                "(no description set)",
              ) ++ raw_escape_sequence("\x1b[0m"),
            )
          '
        '';
      };
      git_status.disabled = true;
      custom.git_status = {
        when = "! jj --ignore-working-copy root";
        command = "starship module git_status";
        style = "";
        description = "Only show git_status if we're not in a jj repo";
      };
      git_commit.disabled = true;
      custom.git_commit = {
        when = "! jj --ignore-working-copy root";
        command = "starship module git_commit";
        style = "";
        description = "Only show git_commit if we're not in a jj repo";
      };
      git_metrics.disabled = true;
      custom.git_metrics = {
        when = "! jj --ignore-working-copy root";
        command = "starship module git_metrics";
        description = "Only show git_metrics if we're not in a jj repo";
        style = "";
      };
      git_branch.disabled = true;
      custom.git_branch = {
        when = "! jj --ignore-working-copy root";
        command = "starship module git_branch";
        description = "Only show git_branch if we're not in a jj repo";
        style = "";
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "Carter McBride";
    userEmail = "18412686+carterworks@users.noreply.github.com";

    delta = {
      enable = true;
      options = {
        line-numbers = true;
      };
    };

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.local.*"
      "CLAUDE.md"
      "AGENTS.md"
      ".cursor/"
      ".worktrees/"
      ".osgrep/"
    ];

    includes = [
      { path = "aliases"; }
    ];

    extraConfig = {
      format.pretty = "%H %ci %ce %ae %d %s";
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      init.defaultBranch = "main";
      apply.whitespace = "fix";
      log.date = "iso";
      pull = {
        ff = "only";
        rebase = true;
      };
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      diff = {
        algorithm = "histogram";
        mnemonicPrefix = true;
        colorMoved = "plain";
        renames = true;
      };
      help.autocorrect = "prompt";
      commit.verbose = true;
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      merge.conflictstyle = "zdiff3";
      credential = {
        "https://github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "https://gist.github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "https://git.corp.adobe.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
      };
    };
  };
}
