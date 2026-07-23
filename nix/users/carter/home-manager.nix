{
  config,
  pkgs,
  lib,
  ...
}:

let
  theme = {
    fonts = {
      monospace = "Iosevka";
      sansSerif = "Inter";
    };
  };
in
{
  home.packages = [
    pkgs.inter
    pkgs.iosevka-bin
  ];

  home.stateVersion = "26.11";
  home.shell.enableShellIntegration = true;
  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  gtk = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    font = {
      name = theme.fonts.sansSerif;
      size = 12;
    };
    theme = {
      name = "Breeze";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "Papirus";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = false;
    gtk4.theme = config.gtk.theme;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = false;
  };
  xdg.configFile."git/aliases".source = ../../../git/aliases;
  xdg.configFile."fish/fish_plugins".source = ../../../fish/fish_plugins;
  xdg.configFile."fish/completions/codex.fish".source = ../../../fish/completions/codex.fish;
  xdg.configFile."fish/completions/oc.fish".text = ''
    complete -c oc -f
    complete -c oc -n 'not __fish_seen_subcommand_from acp agent attach completion db debug export github import mcp models plugin pr providers run serve session stats uninstall upgrade web' -a 'acp agent attach completion db debug export github import mcp models plugin pr providers run serve session stats uninstall upgrade web'
  '';
  xdg.configFile."fish/completions/pnpm.fish".source = ../../../fish/completions/pnpm.fish;
  xdg.configFile."fish/completions/tinty.fish".source = ../../../fish/completions/tinty.fish;
  xdg.configFile."fish/completions/scout.fish".source = ../../../fish/completions/scout.fish;
  xdg.configFile."autostart/vicinae.desktop" = lib.mkIf pkgs.stdenv.isLinux {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Vicinae
      Exec=vicinae server
      Terminal=false
      NoDisplay=true
      X-GNOME-Autostart-enabled=true
    '';
  };
  xdg.configFile."autostart/Handy.desktop" = lib.mkIf pkgs.stdenv.isLinux {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Handy
      Exec=handy --start-hidden
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';
  };
  xdg.configFile."autostart/steam.desktop" = lib.mkIf pkgs.stdenv.isLinux {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Steam
      Exec=steam -silent
      Terminal=false
      X-GNOME-Autostart-enabled=true
    '';
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      cc = "claude --model opus --effort high";
    };
    shellInit = ''
      if test -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" && command -qs babelfish
          cat "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" | babelfish | source
      end
      if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      end
      if test -e /opt/homebrew/bin/brew
          /opt/homebrew/bin/brew shellenv fish | source
      end
      if test -e ~/.lmstudio/bin
          fish_add_path ~/.lmstudio/bin
      end
      fish_add_path ~/.local/bin
      if set -q XDG_CONFIG_HOME
          set -gx PI_CODING_AGENT_DIR "$XDG_CONFIG_HOME/pi/agent"
      else
          set -gx PI_CODING_AGENT_DIR "$HOME/.config/pi/agent"
      end
    '';
    interactiveShellInit = ''
      ${lib.getExe' pkgs.fnox "fnox"} activate fish | source

      if command -qs hx
          set -gx EDITOR hx
      else if command -qs helix
          set -gx EDITOR helix
          alias hx="helix"
      else if command -qs nvim
          set -gx EDITOR nvim
      else if command -qs vim
          set -gx EDITOR vim
      else if command -qs vi
          set -gx EDITOR vi
      else if command -qs micro
          set -gx EDITOR micro
      else if command -qs nano
          set -gx EDITOR nano
      end
    '';
  };

  programs.atuin.enable = true;
  programs.man.generateCaches = pkgs.stdenv.isLinux;
  programs.zsh.enable = true;

  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    icons = "auto";
    extraOptions = [
      "--classify=auto"
      "--group-directories-first"
    ];
  };

  home.sessionVariables = {
    EZA_ICON_SPACING = "2";
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

  programs.gh = {
    enable = true;
    settings = {
      version = "1";
      git_protocol = "ssh";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      ui = {
        paginate = "never";
        editor = "cat";
      };
    };
  };

  programs.zed-editor = {
    package = if pkgs.stdenv.isLinux then pkgs.zed-editor-fhs else null;
    enable = true;
    userSettings = {
      project_panel = {
        dock = "left";
      };
      outline_panel = {
        dock = "right";
      };
      collaboration_panel = {
        dock = "right";
      };
      git_panel = {
        dock = "left";
      };
      lsp = {
        vtsls = {
          settings = {
            typescript = {
              updateImportsOnFileMove = {
                enabled = "always";
              };
            };
            javascript = {
              updateImportsOnFileMove = {
                enabled = "always";
              };
            };
          };
          enable_lsp_tasks = true;
        };
      };
      colorize_brackets = true;
      ui_font_family = lib.mkForce ".SystemUIFont";
      ui_font_size = 16.0;
      buffer_font_size = 17.333333333333332;
      theme = "Base16 selenized-light";
      agent = {
        sidebar_side = "right";
        dock = "right";
        play_sound_when_agent_done = "always";
        model_parameters = [ ];
      };
      autosave = "on_focus_change";
      auto_signature_help = true;
      buffer_font_fallbacks = [
        "Iosevka Nerd Font"
        ".ZedMono"
      ];
      buffer_font_family = "Iosevka";
      buffer_font_features = {
        calt = true;
      };
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
          min_column = 80;
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
        dock = "bottom";
        font_family = "Iosevka Term";
        font_size = 16;
        shell = {
          program = "fish";
        };
      };
      title_bar = {
        show_branch_status_icon = true;
        show_menus = true;
      };
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
  };

  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
    settings = {
      window-theme = "auto";
      command = "sh -c 'command -v fish >/dev/null 2>&1 && exec fish || test -x /run/current-system/sw/bin/fish && exec /run/current-system/sw/bin/fish || exec \"$SHELL\"'";
      shell-integration-features = "ssh-terminfo";
    };
  };

  programs.starship = {
    enable = true;
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

  programs.zellij = {
    enable = true;
    settings = {
      default_shell = "fish";
      theme = "solarized_light";
      default_mode = "locked";
      show_startup_tips = false;
      show_release_notes = false;
      osc8_hyperlinks = true;
    };
  };

  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.local.*"
      "CLAUDE.md"
      "AGENTS.md"
      ".cursor/"
      ".worktrees/"
      ".osgrep/"
      ".scout/"
    ];

    includes = [
      { path = "aliases"; }
      { path = "identity"; }
    ];

    settings = {
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
        "ssh://github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "ssh://gist.github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "ssh://git.corp.adobe.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
      };
    };
  };
}
