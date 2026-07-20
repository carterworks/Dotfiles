{
  pkgs,
  systemUsername,
  ...
}:

let
  truenasHost = "100.80.16.49";

  truenasSmbOptions = [
    "credentials=%d/truenas-smb.creds"
    "uid=carter"
    "gid=users"
    "file_mode=0664"
    "dir_mode=0775"
    "vers=3.1.1"
    "iocharset=utf8"
    "_netdev"
  ];

  mkTruenasMount = share: {
    what = "//${truenasHost}/${share}";
    where = "/mnt/truenas/${share}";
    type = "cifs";

    unitConfig = {
      Requires = [ "tailscaled.service" ];
      After = [
        "tailscaled.service"
        "network-online.target"
      ];
      Wants = [ "network-online.target" ];
    };

    mountConfig = {
      LoadCredentialEncrypted = "truenas-smb.creds:/etc/credstore.encrypted/truenas-smb.creds";
      Options = builtins.concatStringsSep "," truenasSmbOptions;
      TimeoutSec = "10s";
    };
  };

  mkTruenasAutomount = share: {
    where = "/mnt/truenas/${share}";
    wantedBy = [ "multi-user.target" ];

    automountConfig = {
      TimeoutIdleSec = "5min";
    };
  };

  scyllaLocalhostDirectory = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Scylla services</title>
      </head>
      <body>
        <header>
          <h1>Scylla services</h1>
        </header>
        <main>
          <nav aria-label="Scylla services">
            <ul>
              <li><a href="http://cups.scylla.localhost/">CUPS</a></li>
              <li><a href="http://hermes.scylla.localhost/">Hermes Web UI</a></li>
              <li><a href="http://lemonade.scylla.localhost/">Lemonade AI</a></li>
              <li><a href="http://sunshine.scylla.localhost/">Sunshine</a></li>
              <li><a href="http://syncthing.scylla.localhost/">Syncthing</a></li>
            </ul>
          </nav>
        </main>
      </body>
    </html>
  '';
in
{
  imports = [
    ./hardware/scylla.nix
    ./disko/scylla.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 7d";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "ntsync" ];
  boot.zfs.forceImportRoot = false;

  networking.hostId = "8425e349";
  networking.hostName = "scylla";
  networking.networkmanager.enable = true;
  home-manager.users.${systemUsername}.home.sessionVariables.CODEHOME = "$HOME/Projects/code";

  time.timeZone = "America/Denver";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
  };

  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://cups.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy 127.0.0.1:631 {
          header_up Host 127.0.0.1:631
        }
      '';

      "http://scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        root * ${scyllaLocalhostDirectory}
        file_server
      '';

      "http://lemonade.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy 127.0.0.1:13305
      '';

      "http://sunshine.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy https://127.0.0.1:47990 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';

      "http://hermes.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy 127.0.0.1:9119 {
          header_up Host 127.0.0.1:9119
        }
      '';

      "http://syncthing.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy 127.0.0.1:8384
      '';
    };
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.amdgpu.initrd.enable = true;

  hardware.amd-npu = {
    enable = true;
    enableNPU = false;
    enableFastFlowLM = false;
    enableLemonade = true;
    enableROCm = true;
    enableVulkan = true;
    enableImageGen = true;
    lemonade.user = systemUsername;
  };

  hardware.uinput.enable = true;

  users.groups.plugdev = { };

  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
    KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
  '';

  programs.steam = {
    enable = true;
    extest.enable = true;
  };

  programs.gamescope.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  systemd.mounts = [
    (mkTruenasMount "media")
    (mkTruenasMount "users")
  ];

  systemd.automounts = [
    (mkTruenasAutomount "media")
    (mkTruenasAutomount "users")
  ];

  services.syncthing = {
    enable = true;
    user = "carter";
    dataDir = "/home/carter/syncthing";
    configDir = "/home/carter/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
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

  environment.localBinInPath = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  boot.kernel.sysctl."vm.page-cluster" = 0;

  systemd.oomd.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    samba
    vim
    vulkan-tools
  ];

  services.gvfs.enable = true;
  services.openssh.enable = true;
  users.users.carter = {
    extraGroups = [ "plugdev" ];
    linger = true;
  };

  systemd.tmpfiles.rules = [
    "d /games 2775 root games -"
  ];

  system.stateVersion = "25.11";
}
