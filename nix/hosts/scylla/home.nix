{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;

  claudeMcpServers = {
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers.CONTEXT7_API_KEY = "\${CONTEXT7_API_KEY:-}";
    };
    cloudflare = {
      type = "http";
      url = "https://mcp.cloudflare.com/mcp";
    };
    cua-driver = {
      type = "stdio";
      command = "/bin/sh";
      args = [
        "-c"
        "exec cua-driver mcp --socket \"\${XDG_CACHE_HOME:-$HOME/.cache}/cua-driver/cua-driver.sock\""
      ];
    };
    fff = {
      type = "stdio";
      command = "fff-mcp";
      args = [ ];
    };
  };
  claudeMcpServersFile = pkgs.writeText "claude-mcp-servers.json" (builtins.toJSON claudeMcpServers);
in
{
  # Upstream's Home Manager module supports x86_64-linux only; macOS installs
  # the same package as a system app instead.
  # installModel downloads the speech model from the module's own service, so
  # a fresh host can dictate immediately; it is a no-op once the model is
  # present and checksum-verified.
  programs.hex = {
    enable = true;
    autostart = true;
    installModel = true;
    package = pkgs.hex;
    # The Hyprland bind in hypr/bindings.lua names the portal shortcut by this
    # trigger, so changing it means changing that bind too.
    shortcut = "option+space";
  };

  dotfiles.desktopTheme.zenProfile = ".config/zen/jhvzidh2.Default Profile";

  gtk = {
    enable = true;
    font = {
      name = "Inter";
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

  xdg.configFile."autostart/vicinae.desktop" = {
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
  # This desktop is already configured. Closing Vicinae's welcome window does
  # not persist completion; seed its mutable state once, without replacing it.
  home.activation.vicinaeOnboarding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${./complete-vicinae-onboarding.py} ${lib.escapeShellArg config.xdg.stateHome}
  '';
  xdg.configFile."autostart/steam.desktop" = {
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

  home.packages = [ pkgs.claude-code ];

  home.file.".claude/CLAUDE.md".source = ../../../agents/AGENTS.md;

  # Claude Code only reads ~/.claude/skills, while OpenCode reads the shared
  # ~/.agents/skills and its legacy ~/.config/opencode/skills.
  home.activation.claudeSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    skills_dir=${lib.escapeShellArg "${home}/.claude/skills"}
    source_dirs=(
      ${lib.escapeShellArg "${home}/.agents/skills"}
      ${lib.escapeShellArg "${home}/.config/opencode/skills"}
    )
    mkdir -p "$skills_dir"
    for link in "$skills_dir"/*; do
      [ -L "$link" ] || continue
      if [ ! -e "$link" ]; then
        rm -f "$link"
        continue
      fi
      target="$(readlink "$link")"
      for source_dir in "''${source_dirs[@]}"; do
        case "$target" in
          "$source_dir"/*) rm -f "$link" ;;
        esac
      done
    done
    for source_dir in "''${source_dirs[@]}"; do
      [ -d "$source_dir" ] || continue
      for skill in "$source_dir"/*; do
        [ -f "$skill/SKILL.md" ] || continue
        dest="$skills_dir/$(basename "$skill")"
        if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
          ln -s "$skill" "$dest"
        fi
      done
    done
  '';

  # Claude Code stores user-scoped MCP servers in ~/.claude.json, which it also
  # mutates at runtime; merge our entries instead of replacing the file.
  home.activation.claudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    config_file=${lib.escapeShellArg "${home}/.claude.json"}
    tmp="$(mktemp "$config_file.XXXXXX")"
    if [ -f "$config_file" ]; then
      ${pkgs.jq}/bin/jq --slurpfile servers ${claudeMcpServersFile} \
        '.mcpServers = ((.mcpServers // {}) + $servers[0])' "$config_file" >"$tmp"
    else
      ${pkgs.jq}/bin/jq -n --slurpfile servers ${claudeMcpServersFile} \
        '{ mcpServers: $servers[0] }' >"$tmp"
    fi
    chmod 600 "$tmp"
    mv "$tmp" "$config_file"
  '';

  programs.mangohud = {
    enable = true;
    settings = {
      fps = true;
      fps_metrics = "avg,0.01";
      frametime = true;
      frame_timing = lib.mkForce false;
      frame_timing_detailed = false;
      dynamic_frame_timing = false;

      cpu_stats = true;
      cpu_temp = true;
      cpu_load_change = true;
      cpu_load_value = "60,90";
      core_load = true;
      core_load_change = true;
      core_bars = true;

      gpu_stats = true;
      gpu_temp = true;
      gpu_load_change = true;
      gpu_load_value = "60,90";

      ram = true;
      vram = true;

      fsr = true;
      refresh_rate = true;

      position = "top-right";
      table_columns = 3;
      toggle_hud = "Shift_L+F10";
      background_alpha = lib.mkForce 0.25;
      background_color = lib.mkForce "000000";
      text_outline = lib.mkForce false;
    };
  };
}
