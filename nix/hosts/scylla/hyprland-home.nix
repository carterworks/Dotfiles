{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile."uwsm/env-hyprland".text = ''
    export XCURSOR_THEME=Bibata-Modern-Classic
    export XCURSOR_SIZE=24
    export HYPRCURSOR_SIZE=24
    export QT_QPA_PLATFORMTHEME=kde
  '';

  systemd.user.services = {
    # The Cua Driver daemon owns accessibility snapshots and the agent cursor
    # overlay, so it must run inside the desktop session; MCP clients reach it
    # over its socket instead of starting a display-less runtime of their own.
    cua-driver = {
      Unit = {
        Description = "Cua Driver desktop automation daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "wayland-session-waitenv.service" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.cua-driver} serve";
        Environment = [ "CUA_DRIVER_RS_ENABLE_WAYLAND=1" ];
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "wayland-session@hyprland.desktop.target" ];
    };

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
}
