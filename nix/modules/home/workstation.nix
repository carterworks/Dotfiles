{
  config,
  pkgs,
  lib,
  ...
}:

let
  agentInhibitor =
    if pkgs.stdenv.hostPlatform.isDarwin then
      [
        "/usr/bin/caffeinate"
        "-is"
      ]
    else
      [
        (lib.getExe' pkgs.systemd "systemd-inhibit")
        "--what=idle:sleep"
        "--who=coding-agent"
        "--why=Coding agent is running"
        "--mode=block"
      ];

  # The README clones the repo here on every machine. Links point into this
  # checkout rather than the store, so edits apply without a rebuild and
  # programs that rewrite their own config (KDE does) can still write.
  checkout = "${config.home.homeDirectory}/.config/dotfiles";
  # force: Home Manager rejects the symlinks Dotbot made at these paths as
  # collisions; Dotbot also replaced whatever it found.
  link = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${checkout}/${path}";
    force = true;
  };
  # One link per entry leaves other files in the target directory alone.
  linkEach =
    target: dir:
    lib.mapAttrs' (name: _: lib.nameValuePair "${target}/${name}" (link "${dir}/${name}")) (
      builtins.readDir ../../../${dir}
    );
in
{
  imports = [
    ./agent-daemons.nix
    ./desktop-theme
    ./shell.nix
  ];

  dotfiles.desktopTheme = {
    name = "nord-light";
    obsidianVaults = [ "Documents/Notes" ];
  };

  home.packages = [
    pkgs.carapace
    pkgs.inter
    pkgs.iosevka-bin
  ];

  lib.dotfiles = { inherit link linkEach; };

  home.file =
    linkEach ".agents/skills" "agents/skills/personal"
    // linkEach ".agents/skills" "agents/skills/generated"
    // linkEach ".local/bin" "bin"
    // {
      ".npmrc" = link "npm/npmrc";
      ".config/opencode/opencode.jsonc" = link "opencode/opencode.jsonc";
      ".config/opencode/idle-compaction" = link "opencode/idle-compaction";
      ".config/opencode/AGENTS.md" = link "agents/AGENTS.md";
      ".copilot/copilot-instructions.md" = link "agents/AGENTS.md";
    };

  # Keep work-only MCP entries out of the checkout when Copilot edits its config.
  home.activation.copilotMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${../../../copilot/merge-mcp.py} \
      ${lib.escapeShellArg "${checkout}/copilot/mcp-config.json"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.copilot/mcp-config.json"}
  '';

  # A missing checkout would leave every link above dangling. Evaluation
  # cannot see the home directory, so stop before any link is touched.
  home.activation.dotfilesCheckout = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [[ ! -e ${lib.escapeShellArg checkout}/flake.nix ]]; then
      errorEcho ${lib.escapeShellArg "No dotfiles checkout at ${checkout}; clone the repo there (see README.md)."}
      exit 1
    fi
  '';

  home.shell.enableShellIntegration = true;
  xdg.configFile."git/aliases".source = ../../../git/aliases;
  xdg.configFile."fish/completions/codex.fish".source = ../../../fish/completions/codex.fish;
  xdg.configFile."fish/completions/oc.fish".text = ''
    complete -c oc -w opencode2
  '';
  xdg.configFile."fish/completions/pnpm.fish".source = ../../../fish/completions/pnpm.fish;
  xdg.configFile."fish/completions/tinty.fish".source = ../../../fish/completions/tinty.fish;
  xdg.configFile."fish/completions/scout.fish".source = ../../../fish/completions/scout.fish;

  programs.fish = {
    plugins = [
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "bang-bang";
        src = pkgs.fishPlugins.bang-bang.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
    ];
    shellInit = ''
      function mkcd --description 'Create a directory and enter it'
          if test (count $argv) -ne 1
              echo 'Usage: mkcd <directory>' >&2
              return 2
          end

          command mkdir -p -- "$argv[1]"; and cd -- "$argv[1]"
      end

      function __herdr_agent_tab
          set -l herdr_args
          set -l workspace_args
          set -l attach_to_herdr false
          set -l agent_command ${lib.escapeShellArgs agentInhibitor} $argv

          if set -q HERDR_ENV
              command $agent_command
              return
          end

          set herdr_args --session default
          set attach_to_herdr true

          set -l workspace_json (command herdr $herdr_args workspace list 2>&1)
          set -l workspace_status $status

          if test $workspace_status -ne 0
              set -l error_code (printf '%s\n' $workspace_json | ${lib.getExe pkgs.jq} -r '.error.code // empty')
              if test "$error_code" != server_not_running
                  printf '%s\n' $workspace_json >&2
                  return $workspace_status
              end

              command herdr $herdr_args server </dev/null >/dev/null 2>&1 &
              disown $last_pid 2>/dev/null

              for attempt in (seq 1 100)
                  set workspace_json (command herdr $herdr_args workspace list 2>&1)
                  set workspace_status $status
                  test $workspace_status -eq 0; and break
                  sleep 0.05
              end

              if test $workspace_status -ne 0
                  printf '%s\n' $workspace_json >&2
                  return $workspace_status
              end
          end

          set -l workspace_id (printf '%s\n' $workspace_json | ${lib.getExe pkgs.jq} -er '.result.workspaces[] | select(.focused) | .workspace_id')
          or return
          set workspace_args --workspace "$workspace_id"

          set -l tab_json (command herdr $herdr_args tab create $workspace_args --cwd "$PWD" --focus)
          or return
          set -l pane_id (printf '%s\n' $tab_json | ${lib.getExe pkgs.jq} -er '.result.root_pane.pane_id')
          or return
          set -l command_line (string join ' ' -- (string escape -- $agent_command))
          command herdr $herdr_args pane run "$pane_id" "$command_line"
          or return

          if test "$attach_to_herdr" = true
              command herdr session attach default
          end
      end

      function __oc_copy_osc52 --description 'Copy text through OSC 52'
          set -l text "$argv[1]"

          set -l osc52_copied false
          if test -w /dev/tty
              if command -qs base64; and command -qs awk
                  set -l osc52_payload (printf '%s' "$text" | command base64 | string collect)
                  if printf '%s' "$osc52_payload" | command awk '{ payload = payload $0 } END { printf "%c]52;c;%s%c", 27, payload, 7 }' > /dev/tty
                      set osc52_copied true
                  end
              end
          end

          if test "$osc52_copied" != true
              echo 'oc: OSC 52 clipboard copy is unavailable; password was not copied' >&2
              return 1
          end
      end

      function oc --wraps=opencode2 --description 'Launch OpenCode in a new Herdr tab'
          if test "$argv[1]" = pair
              set -l pair_output_file (command mktemp)
              or return

              command opencode2 pair | command tee "$pair_output_file"
              set -l pair_status $pipestatus[1]
              set -l pair_output (command cat "$pair_output_file")
              command rm -f "$pair_output_file"
              if test $pair_status -ne 0
                  return $pair_status
              end

              set -l password (string match --regex --groups-only '^  Password[[:space:]]+(.+)$' -- $pair_output)
              if test (count $password) -ne 1
                  echo 'oc: could not find the password in opencode2 pair output' >&2
                  return 1
              end

              __oc_copy_osc52 "$password"
              return $status
          end

          __herdr_agent_tab opencode2 $argv
      end

      function ocpw --description 'Print and copy the OpenCode pairing password'
          set -l pair_output (command opencode2 pair)
          or return

          set -l password (string match --regex --groups-only '^  Password[[:space:]]+(.+)$' -- $pair_output)
          if test (count $password) -ne 1
              echo 'ocpw: could not find the password in opencode2 pair output' >&2
              return 1
          end

          echo "$password"

          __oc_copy_osc52 "$password"
          return $status
      end

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

      if set -q REX_BIN_DIR; and test -n "$REX_BIN_DIR"
          fish_add_path --path --prepend --move "$REX_BIN_DIR"
      end
    '';
  };

  # zsh/zshrc.zsh sets these up itself: a cached compinit, and starship, atuin,
  # zoxide and direnv from cached init scripts. Home Manager's integrations
  # would rerun each tool's init on every start, and fzf's would take Tab.
  programs.starship.enableZshIntegration = false;
  programs.atuin.enableZshIntegration = false;
  programs.zoxide.enableZshIntegration = false;
  programs.direnv.enableZshIntegration = false;
  programs.fzf.enableZshIntegration = false;
  programs.zellij.settings.default_shell = "zsh";

  programs.zsh = {
    enableCompletion = false;
    history = {
      size = 20000;
      save = 20000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      saveNoDups = true;
      share = true;
    };
    envExtra = ''
      path=(~/.local/bin $path)
      [[ -d ~/.lmstudio/bin ]] && path+=(~/.lmstudio/bin)
    '';
    initContent = ''
      ZSH_PLUGIN_AUTOSUGGESTIONS=${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      ZSH_PLUGIN_COMPLETIONS=${pkgs.zsh-completions}/share/zsh/site-functions
      ZSH_PLUGIN_FAST_SYNTAX=${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
      ZSH_PLUGIN_FZF_TAB=${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      source ${lib.escapeShellArg "${checkout}/zsh/zshrc.zsh"}

      _zff_cache_source fnox ${lib.getExe' pkgs.fnox "fnox"} ${lib.getExe' pkgs.fnox "fnox"} activate zsh
      [[ -x /opt/homebrew/bin/brew ]] && _zff_cache_source brew /opt/homebrew/bin/brew /opt/homebrew/bin/brew shellenv zsh

      if (( $+commands[hx] )); then
        export EDITOR=hx
      elif (( $+commands[helix] )); then
        export EDITOR=helix
        alias hx=helix
      else
        for editor in nvim vim vi micro nano; do
          (( $+commands[$editor] )) && { export EDITOR=$editor; break; }
        done
        unset editor
      fi

      mkcd() {
        if (( $# != 1 )); then
          print -u2 'Usage: mkcd <directory>'
          return 2
        fi
        command mkdir -p -- "$1" && cd -- "$1"
      }

      # Runs a coding agent in a new Herdr tab, starting the Herdr server if needed,
      # with sleep inhibited while it runs.
      __herdr_agent_tab() {
        local -a agent_command=(${lib.escapeShellArgs agentInhibitor} "$@")
        if [[ -n ''${HERDR_ENV-} ]]; then
          command "''${agent_command[@]}"
          return
        fi

        local -a herdr_args=(--session default)
        local workspace_json workspace_status error_code attempt
        workspace_json=$(command herdr $herdr_args workspace list 2>&1)
        workspace_status=$?
        if (( workspace_status != 0 )); then
          error_code=$(print -r -- "$workspace_json" | ${lib.getExe pkgs.jq} -r '.error.code // empty')
          if [[ $error_code != server_not_running ]]; then
            print -ru2 -- "$workspace_json"
            return $workspace_status
          fi
          command herdr $herdr_args server </dev/null >/dev/null 2>&1 &!
          for attempt in {1..100}; do
            workspace_json=$(command herdr $herdr_args workspace list 2>&1)
            workspace_status=$?
            (( workspace_status == 0 )) && break
            sleep 0.05
          done
          if (( workspace_status != 0 )); then
            print -ru2 -- "$workspace_json"
            return $workspace_status
          fi
        fi

        local workspace_id tab_json pane_id
        workspace_id=$(print -r -- "$workspace_json" | ${lib.getExe pkgs.jq} -er '.result.workspaces[] | select(.focused) | .workspace_id') || return
        tab_json=$(command herdr $herdr_args tab create --workspace "$workspace_id" --cwd "$PWD" --focus) || return
        pane_id=$(print -r -- "$tab_json" | ${lib.getExe pkgs.jq} -er '.result.root_pane.pane_id') || return
        command herdr $herdr_args pane run "$pane_id" "''${(j: :)''${(@q-)agent_command}}" || return
        command herdr session attach default
      }

      __oc_copy_osc52() {
        local payload
        if [[ -w /dev/tty ]] && payload=$(print -rn -- "$1" | command base64 | command tr -d '\n'); then
          printf '\e]52;c;%s\a' "$payload" >/dev/tty && return 0
        fi
        print -u2 'oc: OSC 52 clipboard copy is unavailable; password was not copied'
        return 1
      }

      # Prints the one "  Password <value>" line's value from opencode2 pair output.
      __oc_pair_password() {
        local line
        local -a found
        for line in "''${(@f)1}"; do
          [[ $line =~ '^  Password[[:space:]]+(.+)$' ]] && found+=("$match[1]")
        done
        (( $#found == 1 )) && print -r -- "$found[1]"
      }

      oc() {
        if [[ ''${1-} == pair ]]; then
          local output_file pair_status password
          output_file=$(command mktemp) || return
          command opencode2 pair | command tee "$output_file"
          pair_status=''${pipestatus[1]}
          local pair_output=$(<"$output_file")
          command rm -f -- "$output_file"
          (( pair_status == 0 )) || return $pair_status
          if ! password=$(__oc_pair_password "$pair_output"); then
            print -u2 'oc: could not find the password in opencode2 pair output'
            return 1
          fi
          __oc_copy_osc52 "$password"
          return
        fi
        __herdr_agent_tab opencode2 "$@"
      }
      _zff_completes_as[oc]=opencode2

      ocpw() {
        local pair_output password
        pair_output=$(command opencode2 pair) || return
        if ! password=$(__oc_pair_password "$pair_output"); then
          print -u2 'ocpw: could not find the password in opencode2 pair output'
          return 1
        fi
        print -r -- "$password"
        __oc_copy_osc52 "$password"
      }
    '';
  };

  programs.atuin = {
    settings = {
      enter_accept = true;
      sync.records = true;
    };
  };
  programs.man.generateCaches = pkgs.stdenv.hostPlatform.isLinux;

  programs.bat.enable = true;

  home.sessionVariables = {
    CODEHOME = "${config.home.homeDirectory}/Projects/code";
    WORKTREEHOME = "${config.home.homeDirectory}/Projects/code/worktrees";
    COPILOT_SKILLS_DIRS = "${config.home.homeDirectory}/.claude/skills/synced,${config.home.homeDirectory}/.config/opencode/skills";
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
    package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.zed-editor-fhs else null;
    enable = true;
    mutableUserSettings = false;
    mutableUserKeymaps = false;
    mutableUserTasks = false;
    mutableUserDebug = false;
    extensions = [
      "astro"
      "base16"
      "colored-zed-icons-theme"
      "dockerfile"
      "emmet"
      "markdown-oxide"
      "nix"
      "svelte"
      "toml"
    ];
    userKeymaps = [
      {
        context = "Terminal";
        bindings.shift-enter = [
          "terminal::SendText"
          "\u001b\r"
        ];
      }
    ];
    userSettings = {
      debugger.button = false;
      cli_default_open_behavior = "new_window";
      project_panel = {
        dock = "left";
      };
      outline_panel = {
        button = false;
        dock = "right";
      };
      collaboration_panel = {
        button = false;
        dock = "right";
      };
      git_panel = {
        group_by = "status";
        tree_view = false;
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
      file_scan_exclusions = [
        "**/.git"
        "**/.svn"
        "**/.hg"
        "**/.jj"
        "**/CVS"
        "**/.DS_Store"
        "**/Thumbs.db"
        "**/.classpath"
        "**/.settings"
      ];
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
          program = "zsh";
        };
      };
      title_bar = {
        show_branch_status_icon = true;
        show_menus = true;
      };
      agent_servers = {
        cursor.type = "registry";
        opencode = {
          favorite_config_option_values.model = [
            "openai/gpt-5.5/low"
            "openai/gpt-5.5/high"
          ];
          type = "registry";
        };
      };
      context_servers.fff = {
        args = [ ];
        command = "fff-mcp";
        enabled = true;
        env = { };
        remote = false;
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
    package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
    settings = {
      command = lib.getExe config.programs.zsh.package;
      shell-integration-features = "ssh-terminfo,ssh-env";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.local.*"
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
