{ pkgs, ... }:

let
  sunshine-cosmic-randr = pkgs.writeShellApplication {
    name = "sunshine-cosmic-randr";
    runtimeInputs = with pkgs; [ cosmic-randr gawk gnused ];
    text = builtins.readFile ./sunshine-cosmic-randr.sh;
  };
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
          prep-cmd = [
            {
              do = "${sunshine-cosmic-randr}/bin/sunshine-cosmic-randr client DP-2";
              undo = "${sunshine-cosmic-randr}/bin/sunshine-cosmic-randr mode DP-2 3440 1440 99.982";
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
