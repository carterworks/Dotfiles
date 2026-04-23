{ pkgs, ... }:

{
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "Bibata-Modern-Classic";
    HYPRCURSOR_THEME = "24";
  };

  programs.fish.enable = true;

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
          prep-cmd = [
            {
              do = "${pkgs.cosmic-randr}/bin/cosmic-randr mode DP-2 ${"$"}{SUNSHINE_CLIENT_WIDTH} ${"$"}{SUNSHINE_CLIENT_HEIGHT} --refresh ${"$"}{SUNSHINE_CLIENT_FPS}";
              undo = "${pkgs.cosmic-randr}/bin/cosmic-randr mode DP-2 3440 1440 --refresh 99.982";
            }
          ];
        }
      ];
    };
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ];
  };

  users.groups.games = { };
  users.users.carter = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "games"
    ];
  };
}
