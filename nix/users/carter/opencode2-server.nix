{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  home = config.home.homeDirectory;
  opencode2 = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  path = lib.concatStringsSep ":" [
    "${home}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
{
  home.packages = [ opencode2 ];

  systemd.user.services.opencode2 = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "OpenCode V2 background service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe opencode2} serve --service";
      WorkingDirectory = home;
      Environment = [
        "HOME=${home}"
        "PATH=${path}"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  launchd.agents.opencode2 = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [
        (lib.getExe opencode2)
        "serve"
        "--service"
      ];
      WorkingDirectory = home;
      EnvironmentVariables = {
        HOME = home;
        PATH = path;
      };
      KeepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
      ProcessType = "Background";
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/opencode2.log";
      StandardErrorPath = "${home}/Library/Logs/opencode2.error.log";
    };
  };
}
