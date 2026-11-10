{
  config,
  pkgs,
  ...
}:
let
  inherit (config.home-manager.users.carter.dotfiles.desktopTheme.theme) colors;
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
}
