{
  config,
  fleet,
  lib,
  pkgs,
  ...
}:

let
  hermes = pkgs.hermes-agent;
  fnox = pkgs.fnox;
  # hermes services get their secrets from fnox (age-encrypted
  # /var/lib/hermes/.hermes/fnox.toml; age key at
  # /var/lib/hermes/.config/fnox/age.txt) instead of the plaintext
  # .hermes/.env. fnox is invoked with -c because the units run with
  # WorkingDirectory=/var/lib/hermes, and fnox.toml lives one level down.
  fnoxCmd = "${fnox}/bin/fnox -c /var/lib/hermes/.hermes/fnox.toml exec --";

  # A root-run hermes with HERMES_HOME pointed at the service home
  # (`hermes model`, an interactive TUI) rewrites mutable settings as
  # 0600 root:hermes. The unprivileged
  # gateway/dashboard then cannot read them: the gateway logs
  # "Permission denied", silently falls back to a default config,
  # and dies with "No LLM provider configured" — Discord goes
  # quiet. tmpfiles' `z` cannot repair this (it will not walk
  # ownership back off root), so re-assert it explicitly.
  # Never follow a symlink; never touch contents.
  #
  # Hermes owns /var/lib/hermes, so it can swap .hermes for a symlink
  # to anywhere, and --no-dereference guards only the last component.
  # Working from inside the checked directory pins it: a swap after
  # the check no longer changes which files the chown reaches.
  #
  # Inside it, hermes can also swap a file between check and chown, or
  # leave a hard link to a root-owned file elsewhere (only the host-wide
  # fs.protected_hardlinks stops it making one). So each file is opened
  # without following a symlink and checked and chowned through that one
  # descriptor: a regular file with a single link is hermes' own. -I keeps
  # Python from importing modules out of this hermes-owned directory.
  hermesSettingsRepair = pkgs.writeShellScript "hermes-settings-repair" ''
    dir=/var/lib/hermes/.hermes
    if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
      exit 0
    fi
    if ! cd "$dir" || [ "$(pwd -P)" != "$dir" ] || [ "$(${pkgs.coreutils}/bin/stat -c %U .)" != hermes ]; then
      echo "hermes-settings-repair: $dir is not a real directory owned by hermes; refusing" >&2
      exit 1
    fi
    exec ${pkgs.python3.interpreter} -I -c '
    import os, pwd, stat
    hermes = pwd.getpwnam("hermes")
    for name in ("config.yaml", "SOUL.md"):
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_NOCTTY)
        except OSError:
            continue
        st = os.fstat(fd)
        if stat.S_ISREG(st.st_mode) and st.st_nlink == 1:
            os.fchown(fd, hermes.pw_uid, hermes.pw_gid)
        os.close(fd)
    '
  '';

  hermesService = lib.recursiveUpdate {
    # The egress fence is the agent's security boundary: start only while
    # its chain is hooked, and stop along with the firewall.
    requires = [ "firewall.service" ];
    after = [
      "network-online.target"
      "firewall.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/var/lib/hermes/.hermes/config.yaml";
    environment = {
      HOME = "/var/lib/hermes";
      HERMES_HOME = "/var/lib/hermes/.hermes";
      PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin";
    };
    serviceConfig = {
      ExecStartPre = "+${config.eltoro.egress.checkHooked}";
      User = "hermes";
      Group = "hermes";
      Slice = "hermes.slice";
      WorkingDirectory = "/var/lib/hermes";
      RestartSec = "5s";
      # keep the agent from escalating even if it escapes its own config
      NoNewPrivileges = true;
      ProtectSystem = "full";
      ProtectHome = true;
      # Keep credentials and the fnox-managed gateway/channel
      # allowlists read-only in the service namespace. config.yaml
      # stays writable for interactive and dashboard settings;
      # restrictions stored there are therefore not immutable.
      ReadOnlyPaths = [
        "/var/lib/hermes/.hermes/fnox.toml"
        "/var/lib/hermes/.hermes/.env"
        "/var/lib/hermes/.hermes/auth.json"
      ];
      # no tailscaled control socket in the service namespace —
      # the tailscale cli is root's job (see UMask note above;
      # this keeps it blocked even if socket perms ever regress)
      InaccessiblePaths = [ "/run/tailscale" ];
    };
  };
in
{
  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/server.nix
    ./egress.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "eltoro";
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # fish for root
  programs.fish.enable = true;
  users.users.root.shell = pkgs.fish;

  # ssh: key-only root access (deploy target)
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    fleet.adminSshKey
  ];

  # hermes runs as a dedicated unprivileged user — no sudo
  # (disabled below), no wheel membership, no ssh keys, no
  # password login. Its state lives in /var/lib/hermes:
  # ~/.hermes plus the age key at ~/.config/fnox/age.txt.
  # Deploys still come in over root ssh (key-only); interactive
  # admin is done via `runuser --pty -u hermes -- …`. Never run the hermes
  # CLI as root: it would read configuration that hermes can write,
  # which may let the agent run code as root.
  #
  # Pin the identity: the firewall rules match the hermes UID and
  # credential files are owned by it. Letting NixOS reallocate the
  # system UID between generations left stale iptables rules for the
  # old UID, which bypassed the egress and tailnet restrictions.
  users.groups.hermes.gid = 993;
  users.users.hermes = {
    uid = 995;
    isSystemUser = true;
    group = "hermes";
    home = "/var/lib/hermes";
    createHome = true;
    shell = pkgs.fish;
  };

  # Hermes reads .env during startup even when fnox supplies the
  # secrets. Root-run onboarding/import can recreate it as 0600
  # root:hermes, which makes the hermes service fail before fnox
  # has any useful effect. Keep the service-readable, root-owned
  # mode across boot and NixOS activation without exposing it to
  # writes by the service user.
  systemd.tmpfiles.rules = [
    # Settings are mutable state, including after root-run onboarding.
    "z /var/lib/hermes/.hermes/config.yaml 0600 hermes hermes -"
    "z /var/lib/hermes/.hermes/SOUL.md 0600 hermes hermes -"
    "z /var/lib/hermes/.hermes/fnox.toml 0600 hermes hermes -"
    "z /var/lib/hermes/.hermes/auth.json 0600 hermes hermes -"
    "z /var/lib/hermes/.config/fnox/age.txt 0600 hermes hermes -"
    "z /var/lib/hermes/.hermes/.env 0640 root hermes -"
    "d /var/lib/hermes/workspace 0750 hermes hermes -"
  ];

  # tmpfiles refuses the unsafe user-owned-directory -> root-owned
  # file transition left by root-run onboarding, and its `z` rule
  # will not walk ownership back off root either. Repair ownership
  # first, without following a symlink; tmpfiles then enforces mode.
  #
  # Hermes can make the repair refuse at will. Failing activation for it
  # would make every deploy look failed though the system switched, so
  # only warn here; the timer's unit still fails, visibly.
  system.activationScripts.hermes-settings = {
    deps = [ "users" ];
    text = ''
      ${hermesSettingsRepair} ||
        echo "warning: hermes settings were not repaired; see above and inspect /var/lib/hermes/.hermes. The system switched regardless." >&2
    '';
  };

  # That activation repair only runs at deploy/boot, but the drift
  # happens mid-session: the gateway does not exit when it loses
  # the config (it keeps running on defaults and spamming the log),
  # so nothing would heal it until the next deploy. Re-assert
  # ownership on a timer, bounding any outage to the interval.
  systemd.services.hermes-settings-repair = {
    description = "Re-assert hermes ownership of mutable settings";
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = hermesSettingsRepair;
    };
  };

  systemd.timers.hermes-settings-repair = {
    description = "Periodically repair hermes settings ownership";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
      AccuracySec = "10s";
      Unit = "hermes-settings-repair.service";
    };
  };

  # nothing on this box should be able to escalate: the workload
  # is unprivileged and administration happens as root over ssh
  security.sudo.enable = false;

  # tailscale
  services.tailscale.enable = true;
  # tailscaled creates its control socket world-writable by
  # default (srw-rw-rw-, explicitly chmod'd by tailscaled, so a
  # umask doesn't stick), which would let the hermes user drive
  # tailscaled (down/logout/advertise-exit-node) and undo the
  # network isolation from inside the ct. force 0600 after each
  # start — the tailscale cli becomes root-only.
  systemd.services.tailscaled.serviceConfig.ExecStartPost =
    "+/run/current-system/sw/bin/chmod 0600 /run/tailscale/tailscaled.sock";
  networking.firewall = {
    enable = true;
    # The dashboard (9119) is reached over the tailnet only; opening it in
    # allowedTCPPorts would expose it on the LAN side too.
    trustedInterfaces = [ "tailscale0" ];
  };

  environment.systemPackages = with pkgs; [
    hermes
    git
    ripgrep
    fd
    nodejs_24
    pnpm
    helix
    vim
    ffmpeg # hermes shells out to it to transcode voice audio
    (python3.withPackages (ps: [ ps.pip ]))
    uv
    fnox # secret manager: resolves /root/.hermes/fnox.toml via age
    pkgs.age # age-keygen; fnox reads the key from ~/.config/fnox/age.txt
  ];

  # hard resource ceiling for the whole hermes family (both units
  # + everything they spawn): a runaway agent must never be able
  # to starve ssh/root out of cpu or memory, so you can always
  # get in and `systemctl stop hermes-gateway hermes-dashboard`.
  # gateway normally peaks ~330M — 2G hard max leaves ~1G of
  # headroom for the box itself.
  systemd.slices.hermes = {
    description = "Hermes Agent resource cap";
    sliceConfig = {
      CPUQuota = "150%";
      MemoryHigh = "1536M";
      MemoryMax = "2G";
    };
  };

  # hermes gateway — stays off until first-run onboarding creates
  # /var/lib/hermes/.hermes/config.yaml
  #
  # The unit is declaratively managed here (NixOS owns the /etc/systemd/system
  # symlink), so NEVER use `hermes gateway setup` / `hermes gateway restart` on
  # eltoro: the wizard's trailing service step tries to rewrite the unit file
  # (it can't — the unit runs unprivileged and can't touch /etc — but don't
  # tempt it). Its config prompts are fine — they just write $HERMES_HOME/.env.
  # Restart with `systemctl restart hermes-gateway` (as root).
  #
  # Secrets come from fnox (age-encrypted fnox.toml) via the fnoxCmd wrapper;
  # if a new secret is added through the wizard it lands in the plaintext .env,
  # so re-import it as hermes:
  # runuser --pty -u hermes -- sh -c 'cd /var/lib/hermes/.hermes && fnox import -i .env --provider age --force'
  systemd.services.hermes-gateway = hermesService {
    description = "Hermes Agent Gateway";
    environment = {
      MESSAGING_CWD = "/var/lib/hermes/workspace";
      # no approval prompts: the agent is fenced from the LAN by
      # the host-side proxmox firewall and from the internet by
      # the egress ipset, so "ask carter" is a dead end that only
      # stalls the agent. this freezes yolo for the gateway process;
      # approvals.mode: off in config.yaml covers CLI/admin runs.
      HERMES_YOLO_MODE = "1";
    };
    serviceConfig = {
      ExecStart = "${fnoxCmd} ${hermes}/bin/hermes gateway run --replace";
      Restart = "always";
    };
  };

  # hermes dashboard (http://eltoro:9119 from the tailnet)
  systemd.services.hermes-dashboard = hermesService {
    description = "Hermes Agent Web Dashboard";
    serviceConfig = {
      ExecStart = "${fnoxCmd} ${hermes}/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open";
      Restart = "on-failure";
    };
  };

  system.stateVersion = "26.05";
}
