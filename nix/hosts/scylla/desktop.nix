{ pkgs, ... }:

let
  sunshine-kscreen-doctor = pkgs.writeShellApplication {
    name = "sunshine-kscreen-doctor";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      kdePackages.libkscreen
      hyprland
      gnused
      util-linux
    ];
    text = builtins.readFile ./sunshine-kscreen-doctor.sh;
  };
  sunshinePrepCmd = [
    {
      do = "${sunshine-kscreen-doctor}/bin/sunshine-kscreen-doctor push-client";
      undo = "${sunshine-kscreen-doctor}/bin/sunshine-kscreen-doctor pop";
    }
  ];
in
{
  fonts.packages = [ pkgs.nerd-fonts.iosevka ];

  environment.systemPackages = with pkgs; [
    bambu-studio
    bibata-cursors
    discord
    dolphin-emu
    google-chrome
    heroic
    kdePackages.karousel
    papirus-icon-theme
    playerctl
    protonplus
    sgdboop
    ship-of-harkinian
    # Vulkan is the Linux counterpart of the Mac's Metal build.
    stable-diffusion-cpp-vulkan
    systemd-lsp
    telegram-desktop
    trayscale
    vicinae
    wallust
    wl-clipboard
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  services.desktopManager.plasma6 = {
    enable = true;
  };
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole
    elisa
    kate
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common.default = [ "gtk" ];
      kde.default = [
        "kde"
        "gtk"
      ];
    };
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk
    ];
  };

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    autoLogin.enable = true;
    autoLogin.user = "carter";
    plasma-login-manager.enable = true;
  };

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          "color-scheme" = "prefer-light";
          "icon-theme" = "Papirus";
        };
      };
    }
  ];

  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    settings.capture = "kms";
    applications = {
      apps = [
        {
          name = "Desktop";
          image-path = "desktop.png";
          prep-cmd = sunshinePrepCmd;
        }
        {
          name = "Steam Big Picture";
          detached = [ "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture" ];
          image-path = "steam.png";
          prep-cmd = sunshinePrepCmd ++ [
            {
              undo = "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://close/bigpicture";
            }
          ];
        }
      ];
    };
  };
}
