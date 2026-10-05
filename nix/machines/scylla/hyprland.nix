{
  config,
  pkgs,
  systemUsername,
  ...
}:
let
  themeName = config.home-manager.users.${systemUsername}.dotfiles.desktopTheme.name;
  colors = (import (../../users/carter/themes + "/${themeName}.nix")).colors;
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
    ];
    text = ''
      if ! region="$(slurp -b '${colors.background}99' -c '${colors.focus}ff' -s '${colors.selection}44')"; then
        exit 0
      fi
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      grim -g "$region" -t ppm - | satty --filename - \
        --output-filename "$directory/screenshot-$(date +%Y%m%d-%H%M%S-%N).png" \
        --copy-command "wl-copy --type image/png" \
        --actions-on-enter save-to-clipboard,save-to-file,exit
    '';
  };
in
{
  # Keep Plasma installed as a fallback and reuse its applications and services.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    "org.freedesktop.impl.portal.Secret" = [ "kwallet" ];
  };

  environment.systemPackages = [
    screenshot
    pkgs.quickshell
    pkgs.kdePackages.polkit-kde-agent-1
  ];

  # Sunshine initializes its GTK tray only once. Wait for the session environment
  # and tray host, but still allow streaming when no tray host is available.
  systemd.user.services.sunshine = {
    after = [ "wayland-session-waitenv.service" ];
    serviceConfig.ExecStartPre = pkgs.writeShellScript "sunshine-wait-for-tray" ''
      for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
        if ${pkgs.systemd}/bin/busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      echo "No tray host available; starting Sunshine without waiting further."
    '';
  };

  home-manager.users.${systemUsername} = { config, lib, ... }: {
    # Vicinae's Qt OpenGL backend crashes when opening its Wayland window on
    # this host. Keep the workaround local to its existing autostart service.
    #TODO: Switch Vicinae to hardware rendering when nixpkgs updates; verify
    # opening the launcher on the real GPU before removing this override.
    xdg.configFile."systemd/user/app-vicinae@autostart.service.d/rendering.conf".text = ''
      [Service]
      Environment=QT_QUICK_BACKEND=software
    '';

    xdg.configFile."uwsm/env-hyprland".text = ''
      export XCURSOR_THEME=Bibata-Modern-Classic
      export XCURSOR_SIZE=24
      export HYPRCURSOR_SIZE=24
      export QT_QPA_PLATFORMTHEME=kde
    '';

    systemd.user.services = {
      hyprland-trayscale = {
        Unit = {
          Description = "Tailscale system tray for Hyprland";
          PartOf = [ "graphical-session.target" ];
          After = [ "wayland-session-waitenv.service" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.trayscale} --hide-window";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "wayland-session@hyprland.desktop.target" ];
      };

      quickshell = {
        Unit = {
          Description = "Custom Hyprland sidebar and wallpaper";
          PartOf = [ "graphical-session.target" ];
          # The UWSM session target precedes graphical-session.target, so its
          # wanted services must not wait for that target (an ordering cycle).
          After = [ "wayland-session-waitenv.service" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.quickshell} --path ${config.xdg.configHome}/quickshell";
          Environment = [ "QT_QUICK_CONTROLS_STYLE=Basic" ];
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "wayland-session@hyprland.desktop.target" ];
      };

      hyprland-polkit = {
        Unit = {
          Description = "KDE authentication agent for Hyprland";
          PartOf = [ "graphical-session.target" ];
          After = [ "wayland-session-waitenv.service" ];
        };
        Service = {
          ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "wayland-session@hyprland.desktop.target" ];
      };

    };
  };
}
