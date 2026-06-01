{ pkgs, ... }:

let
  sunshine-kscreen-doctor = pkgs.writeShellApplication {
    name = "sunshine-kscreen-doctor";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      kdePackages.libkscreen
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
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  programs.fish.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

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
      "uinput"
    ];
  };
}
