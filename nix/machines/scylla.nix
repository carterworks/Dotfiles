{
  pkgs,
  systemUsername,
  ...
}:

let
  opencodePort = 4096;
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
in
{
  imports = [
    ./hardware/scylla.nix
    ./disko/scylla.nix
  ];

  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "ntsync" ];
  boot.zfs.forceImportRoot = false;

  networking.hostId = "8425e349";
  networking.hostName = "scylla";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ opencodePort ];

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

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.initrd.enable = true;

  hardware.uinput.enable = true;

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
  ];

  services.gvfs.enable = true;
  services.openssh.enable = true;
  users.users.carter.linger = true;

  systemd.tmpfiles.rules = [
    "d /games 2775 root games -"
  ];

  system.stateVersion = "25.11";
}
