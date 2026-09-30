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
      jq
      kdePackages.qttools
      kdotool
    ];
    text = builtins.readFile ./waybar-kde-workspaces.sh;
  };
  waybarKdeWindow = pkgs.writeShellApplication {
    name = "waybar-kde-window";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      jq
      kdotool
    ];
    text = builtins.readFile ./waybar-kde-window.sh;
  };
  waybar = pkgs.waybar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/modules/sni/tray.cpp \
        --replace-fail 'box_(bar.orientation, 0)' \
        'box_(config["orientation"].asString() == "horizontal" ? Gtk::ORIENTATION_HORIZONTAL : bar.orientation, 0)'
    '';
  });
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

  programs.waybar = {
    enable = true;
    package = waybar;
    systemd = {
      enable = true;
      targets = [ "graphical-session.target" ];
    };
    settings = {
      mainBar = {
        layer = "top";
        position = "left";
        width = 380;
        exclusive = true;
        passthrough = false;
        gtk-layer-shell = true;
        spacing = 6;
        margin-top = 8;
        margin-bottom = 8;
        margin-left = 8;
        modules-left = [
          "custom/workspaces"
          "custom/window-1"
          "custom/window-2"
          "custom/window-3"
          "custom/window-4"
          "custom/window-5"
          "custom/window-6"
          "custom/window-7"
          "custom/window-8"
        ];
        modules-center = [ "custom/spacer" ];
        modules-right = [
          "group/tray"
          "custom/media"
          "clock#time"
          "clock#date"
        ];
        "custom/workspaces" = {
          exec = "${lib.getExe waybarKdeWorkspaces}";
          return-type = "json";
          interval = 2;
          format = "{text}";
          tooltip = true;
          on-click = "qdbus org.kde.KWin /KWin nextDesktop";
          on-click-right = "qdbus org.kde.KWin /KWin previousDesktop";
        };
        "custom/window-1" = {
          exec = "${lib.getExe waybarKdeWindow} render 1";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 1";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 1";
        };
        "custom/window-2" = {
          exec = "${lib.getExe waybarKdeWindow} render 2";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 2";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 2";
        };
        "custom/window-3" = {
          exec = "${lib.getExe waybarKdeWindow} render 3";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 3";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 3";
        };
        "custom/window-4" = {
          exec = "${lib.getExe waybarKdeWindow} render 4";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 4";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 4";
        };
        "custom/window-5" = {
          exec = "${lib.getExe waybarKdeWindow} render 5";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 5";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 5";
        };
        "custom/window-6" = {
          exec = "${lib.getExe waybarKdeWindow} render 6";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 6";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 6";
        };
        "custom/window-7" = {
          exec = "${lib.getExe waybarKdeWindow} render 7";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 7";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 7";
        };
        "custom/window-8" = {
          exec = "${lib.getExe waybarKdeWindow} render 8";
          return-type = "json";
          interval = 1;
          format = "{text}";
          hide-empty-text = true;
          justify = "left";
          align = 0;
          tooltip = true;
          on-click = "${lib.getExe waybarKdeWindow} activate 8";
          on-click-middle = "${lib.getExe waybarKdeWindow} close 8";
        };
        "custom/spacer" = {
          format = " ";
          min-length = 1;
          tooltip = false;
        };
        "group/tray" = {
          orientation = "horizontal";
          modules = [ "tray" ];
        };
        tray = {
          orientation = "horizontal";
          icon-size = 18;
          spacing = 6;
          show-passive-items = true;
        };
        "custom/media" = {
          format = "⏯ »";
          tooltip = true;
          tooltip-format = "Left: play/pause · right: next · middle: previous";
          on-click = "playerctl play-pause";
          on-click-right = "playerctl next";
          on-click-middle = "playerctl previous";
        };
        "clock#time" = {
          format = "{:%H\n%M}";
          tooltip-format = "{:%Y-%m-%d %H:%M:%S}";
        };
        "clock#date" = {
          format = "{:%a\n%d\n%b}";
          tooltip-format = "{:%Y-%m-%d}";
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
      #custom-workspaces {
        font-size: 11px;
        letter-spacing: 1px;
        color: #cdd6f4;
        padding: 4px 0;
      }
      #custom-workspaces label {
        padding: 3px 0;
      }
      #custom-window-1,
      #custom-window-2,
      #custom-window-3,
      #custom-window-4,
      #custom-window-5,
      #custom-window-6,
      #custom-window-7,
      #custom-window-8 {
        min-height: 34px;
        margin: 2px 5px;
        padding: 5px 3px;
        border-radius: 12px;
        color: #bac2de;
        background: transparent;
      }
      #custom-window-1:hover,
      #custom-window-2:hover,
      #custom-window-3:hover,
      #custom-window-4:hover,
      #custom-window-5:hover,
      #custom-window-6:hover,
      #custom-window-7:hover,
      #custom-window-8:hover {
        background: rgba(255, 255, 255, 0.12);
      }
      #group-tray,
      #tray {
        min-height: 28px;
        padding: 0;
      }
      #tray > .passive,
      #tray > .active,
      #tray > .needs-attention {
        margin: 0 2px;
      }
      #custom-media,
      #clock.time,
      #clock.date {
        padding: 4px 0;
        color: #bac2de;
      }
      #custom-media {
        color: #f9e2af;
      }
      #clock.time {
        font-weight: 600;
        font-size: 13px;
        color: #ffffff;
      }
      #clock.date {
        color: #a6adc8;
      }
    '';
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
