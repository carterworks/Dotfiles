{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  home = config.home.homeDirectory;
  opencode2 = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  t3 = self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-cli;

  opencode2Port = 49374;
  t3Port = 3773;

  # `--service` keeps the managed server's pairing password and client
  # registration stable; the service manager owns the lifecycle, so stop it
  # with systemctl/launchctl rather than `opencode2 service stop`.
  opencode2Args = [
    "serve"
    "--service"
    "--hostname"
    "0.0.0.0"
    "--port"
    (toString opencode2Port)
  ];
  # Keep the port and origin stable: paired clients are scoped to the origin,
  # so changing either forces every phone and desktop to pair again.
  # Tailscale Serve is the only ingress; bind loopback so nothing bypasses it.
  t3Args = [
    "serve"
    "--mode"
    "web"
    "--host"
    "127.0.0.1"
    "--port"
    (toString t3Port)
    "--no-browser"
  ];

  mkSystemdService = description: executable: args: {
    Unit = {
      Description = description;
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${executable} ${lib.concatStringsSep " " args}";
      WorkingDirectory = home;
      Restart = "always";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # LaunchAgents do not inherit a login shell's PATH, so start through fish's
  # login init to pick up the path nix-darwin computes instead of baking one in.
  mkLaunchdAgent = name: executable: args: {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [
        "${pkgs.fish}/bin/fish"
        "--login"
        "--command"
        "exec ${lib.escapeShellArgs ([ executable ] ++ args)}"
      ];
      WorkingDirectory = home;
      KeepAlive = true;
      ProcessType = "Background";
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/${name}.log";
      StandardErrorPath = "${home}/Library/Logs/${name}.error.log";
    };
  };

  # Pairing is required per host and per client, and can only be done while the
  # server is up. Keep the link command repeatable for hosts that come and go.
  t3pair = pkgs.writeShellApplication {
    name = "t3pair";
    text = ''
      exec ${t3}/bin/t3 pair --tailscale --tailscale-serve-port 9443 "$@"
    '';
  };
in
{
  home.packages = [ t3pair ];
  # Leave Environment alone: the user manager already carries the Nix profile
  # and system paths, and duplicating them here drifts from the live session.
  systemd.user.services.opencode2 = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    mkSystemdService "OpenCode 2 background server" "${opencode2}/bin/opencode2" opencode2Args
  );
  systemd.user.services.t3 = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    mkSystemdService "T3 Code background server" "${t3}/bin/t3" t3Args
  );

  launchd.agents.opencode2 = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    mkLaunchdAgent "opencode2" "${opencode2}/bin/opencode2" opencode2Args
  );
  launchd.agents.t3 = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    mkLaunchdAgent "t3" "${t3}/bin/t3" t3Args
  );
}
