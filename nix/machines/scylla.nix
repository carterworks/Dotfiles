{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware/scylla.nix
    ./disko/scylla.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostId = "8425e349";
  networking.hostName = "scylla";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Denver";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = false;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_580;

  programs.steam.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.syncthing = {
    enable = true;
    user = "carter";
    dataDir = "/home/carter/syncthing";
    configDir = "/home/carter/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [
        "gtk"
        "hyprland"
      ];
    };
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "carter";
    sddm.enable = true;
    sddm.wayland.enable = true;
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

  environment.systemPackages = with pkgs; [
    cifs-utils
    samba
    vim
  ];

  services.gvfs.enable = true;
  services.openssh.enable = true;

  systemd.tmpfiles.rules = [
    "d /games 2775 root games -"
  ];

  system.stateVersion = "25.11";
}
