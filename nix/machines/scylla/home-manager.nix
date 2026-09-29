{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  hermes = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  waybarKdeWorkspaces = pkgs.writeShellApplication {
    name = "waybar-kde-workspaces";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      kdePackages.qttools
    ];
    text = builtins.readFile ./waybar-kde-workspaces.sh;
  };
in
{
  home.packages = [
    hermes
    pkgs.wbg
  ];

  # Scylla wallpaper via wbg (Wayland layer-shell). The image lives in
  # this repo at assets/wallpapers/01-miasma.jpg; Plasma itself is set
  # to solid black (see kde/plasma-org.kde.plasma.desktop-appletsrc)
  # so wbg is the only visible background.
  systemd.user.services.wbg = {
    Unit = {
      Description = "Set desktop wallpaper with wbg";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.wbg} ${config.home.homeDirectory}/.config/dotfiles/assets/wallpapers/01-miasma.jpg";
      Restart = "always";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "graphical-session.target" ];
    };
    settings = {
      mainBar = {
        layer = "top";
        position = "left";
        width = 56;
        exclusive = true;
        passthrough = false;
        gtk-layer-shell = true;
        spacing = 8;
        margin-top = 8;
        margin-bottom = 8;
        margin-left = 8;
        modules-start = [
          "custom/launcher"
          "custom/workspaces"
        ];
        modules-center = [ "wlr/taskbar" ];
        modules-end = [
          "tray"
          "wireplumber"
          "network"
          "cpu"
          "memory"
          "clock"
          "custom/power"
        ];
        "custom/launcher" = {
          format = "✦";
          tooltip = true;
          tooltip-format = "Vicinae launcher";
          on-click = "vicinae toggle";
        };
        "custom/workspaces" = {
          exec = "${lib.getExe waybarKdeWorkspaces}";
          return-type = "json";
          interval = 2;
          format = "{text}";
          tooltip = true;
          on-click = "qdbus org.kde.KWin /KWin nextDesktop";
          on-click-right = "qdbus org.kde.KWin /KWin previousDesktop";
        };
        "wlr/taskbar" = {
          format = "{icon}";
          icon-size = 22;
          spacing = 6;
          on-click = "activate";
          on-click-middle = "close";
          tooltip-format = "{app}: {title}";
        };
        tray = {
          icon-size = 18;
          spacing = 6;
          show-passive-items = true;
        };
        wireplumber = {
          format = "{volume}% {icon}";
          format-muted = " muted";
          format-icons = [
            ""
            ""
            ""
          ];
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          tooltip-format = "Volume: {volume}%";
        };
        network = {
          format-ethernet = " {ipaddr}";
          format-wifi = " {essid}";
          format-disconnected = "⚠ offline";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          interval = 10;
        };
        cpu = {
          format = "{usage}% ";
          interval = 2;
        };
        memory = {
          format = "{}% ";
          interval = 10;
        };
        clock = {
          format = "{:%H\n%M}";
          format-alt = "{:%a\n%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          timezone = "America/Denver";
        };
        "custom/power" = {
          format = "⏻";
          tooltip = true;
          tooltip-format = "Left: logout dialogue, right: reboot, middle: shutdown";
          on-click = "qdbus org.kde.Shutdown /Shutdown logout";
          on-click-right = "qdbus org.kde.Shutdown /Shutdown logoutAndReboot";
          on-click-middle = "qdbus org.kde.Shutdown /Shutdown logoutAndShutdown";
        };
      };
    };
    style = ''
      * {
        font-family: Inter, "Iosevka Nerd Font", sans-serif;
        font-size: 12px;
        border: none;
        border-radius: 0;
      }
      window#waybar {
        background: rgba(18, 18, 26, 0.78);
        border: 1px solid rgba(255, 255, 255, 0.09);
        border-radius: 18px;
        color: #cdd6f4;
      }
      tooltip {
        background: rgba(18, 18, 26, 0.95);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 12px;
      }
      #custom-launcher {
        font-size: 20px;
        color: #8ab4ff;
        padding: 10px 0 4px 0;
      }
      #custom-workspaces {
        font-size: 11px;
        letter-spacing: 1px;
        color: #cdd6f4;
        padding: 4px 0;
      }
      #wlr-taskbar button {
        padding: 5px;
        margin: 2px 6px;
        border-radius: 12px;
        background: transparent;
      }
      #wlr-taskbar button.active {
        background: rgba(138, 180, 255, 0.22);
      }
      #wlr-taskbar button:hover {
        background: rgba(255, 255, 255, 0.12);
      }
      #tray,
      #wireplumber,
      #network,
      #cpu,
      #memory,
      #clock {
        padding: 4px 0;
        color: #bac2de;
      }
      #clock {
        font-weight: 600;
        color: #ffffff;
        font-size: 13px;
      }
      #custom-power {
        font-size: 16px;
        color: #f38ba8;
        padding: 4px 0 10px 0;
      }
    '';
  };

  xdg.dataFile."applications/brave-agent.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Brave Browser (Agent)
    GenericName=Web Browser with CDP
    Exec=brave --password-store=kwallet6 --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 %U
    TryExec=brave
    Terminal=false
    Categories=Network;WebBrowser;
    MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
  '';
  systemd.user.services.hermes-agent = {
    Unit = {
      Description = "Hermes Agent Gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${lib.getExe' pkgs.fnox "fnox"} exec --non-interactive -- ${hermes}/bin/hermes gateway run --replace";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "MESSAGING_CWD=${config.home.homeDirectory}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.hermes-dashboard = {
    Unit = {
      Description = "Hermes Agent Web Dashboard";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${hermes}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
