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

  systemMetricsLogScript = pkgs.writeShellScript "system-metrics-log" ''
    set -euo pipefail

    log_dir=/var/lib/system-metrics
    log_file="$log_dir/$(date +%F).tsv"
    state_file="$log_dir/.cpu-stat"
    mkdir -p "$log_dir"

    if [[ ! -e "$log_file" ]]; then
      printf 'timestamp\tcpu_temp_c\tload_1\tload_5\tload_15\tcpu_util_pct\ttop_cpu\ttop_memory\n' > "$log_file"
    fi

    cpu_temp_millic=$(for hwmon in /sys/class/hwmon/hwmon*; do
      [[ "$(<"$hwmon/name")" == coretemp && -r "$hwmon/temp1_input" ]] || continue
      cat "$hwmon/temp1_input"
      break
    done)
    cpu_temp_c=$(awk -v temp="$cpu_temp_millic" 'BEGIN { printf "%.1f", temp / 1000 }')

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_total=$((idle + iowait))
    cpu_util_pct=0.0
    if [[ -r "$state_file" ]]; then
      read -r old_total old_idle < "$state_file"
      total_delta=$((total - old_total))
      idle_delta=$((idle_total - old_idle))
      if (( total_delta > 0 )); then
        cpu_util_pct=$(awk -v total="$total_delta" -v idle="$idle_delta" 'BEGIN { printf "%.1f", 100 * (total - idle) / total }')
      fi
    fi
    printf '%s %s\n' "$total" "$idle_total" > "$state_file"

    read -r load_1 load_5 load_15 _ < /proc/loadavg
    top_cpu=$(ps -eo pid=,etimes=,pcpu=,comm= --sort=-pcpu | awk '$2 >= 60 && count < 5 { pid = $1; cpu = $3; $1 = ""; $2 = ""; $3 = ""; sub(/^ +/, ""); gsub(/[;\t\r\n]/, "_"); printf "%s%s:%s:%s%%", (count ? ";" : ""), pid, $0, cpu; count++ }')
    top_memory=$(ps -eo pid=,rss=,comm= --sort=-rss | awk 'count < 5 { pid = $1; rss = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); gsub(/[;\t\r\n]/, "_"); printf "%s%s:%s:%sKiB", (count ? ";" : ""), pid, $0, rss; count++ }')

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date --iso-8601=seconds)" "$cpu_temp_c" "$load_1" "$load_5" "$load_15" \
      "$cpu_util_pct" "$top_cpu" "$top_memory" >> "$log_file"
  '';

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
              <li><a href="http://diffusion.scylla.localhost/">stable-diffusion.cpp</a></li>
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
  networking.firewall.enable = false;
  networking.networkmanager.enable = true;
  home-manager.users.${systemUsername} = {
    imports = [ ./scylla/home-manager.nix ];
    home.sessionVariables.CODEHOME = "$HOME/Projects/code";
  };

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

      "http://diffusion.scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy 127.0.0.1:7860
      '';

      "http://scylla.localhost".extraConfig = ''
        bind 127.0.0.1 ::1
        root * ${scyllaLocalhostDirectory}
        file_server
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

  systemd.services.system-metrics-log = {
    description = "Log CPU temperature, load, and top processes";
    path = with pkgs; [
      coreutils
      gawk
      procps
    ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "system-metrics";
      StateDirectoryMode = "0755";
    };
    script = "${systemMetricsLogScript}";
  };

  systemd.timers.system-metrics-log = {
    description = "Sample CPU metrics every 10 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:*:00/10";
      Persistent = true;
      AccuracySec = "1s";
    };
  };

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
    "d /var/lib/system-metrics 0755 root root 14d"
  ];

  system.stateVersion = "25.11";
}
