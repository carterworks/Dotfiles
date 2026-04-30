{ pkgs, ... }:

let
  sunshine-cosmic-randr = pkgs.writeShellApplication {
    name = "sunshine-cosmic-randr";
    runtimeInputs = with pkgs; [
      coreutils
      cosmic-randr
      gawk
      gnused
      util-linux
    ];
    text = builtins.readFile ./sunshine-cosmic-randr.sh;
  };
  sunshinePrepCmd = [
    {
      do = "${sunshine-cosmic-randr}/bin/sunshine-cosmic-randr push-client";
      undo = "${sunshine-cosmic-randr}/bin/sunshine-cosmic-randr pop";
    }
  ];
in
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
    package = pkgs.sunshine.override {
      cudaSupport = true;
      cudaPackages = pkgs.cudaPackages;
    };
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
