{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.fnox;
  unitName = name: "fnox-secret-${name}";
in
{
  options.dotfiles.fnox = {
    file = lib.mkOption {
      type = lib.types.path;
      default = ../../../secrets/fnox.toml;
      description = "fnox config whose age-encrypted values are decrypted with this host's SSH host key.";
    };
    secrets = lib.mkOption {
      default = { };
      description = "Secrets decrypted, each by its own unit, into files on /run before the units that require them.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.str; };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
            };
            requiredBy = lib.mkOption { type = lib.types.listOf lib.types.str; };
          };
        }
      );
    };
  };

  config.systemd.services = lib.mapAttrs' (
    name: secret:
    lib.nameValuePair (unitName name) {
      description = "Decrypt the ${name} secret";
      inherit (secret) requiredBy;
      before = secret.requiredBy;
      path = [ pkgs.fnox ];
      # The global config would merge root's own fnox settings into this one.
      environment = {
        FNOX_CONFIG_DIR = "/var/empty";
        FNOX_AGE_KEY_FILE = "/etc/ssh/ssh_host_ed25519_key";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      # Values are stored base64-encoded so that they come back byte for byte.
      # Writing to a temporary file and renaming means a consumer never sees a
      # partial or wrongly owned file.
      script = ''
        set -o pipefail
        mkdir -p ${lib.escapeShellArg (dirOf secret.path)}
        tmp=$(mktemp ${lib.escapeShellArg "${secret.path}.XXXXXX"})
        trap 'rm -f "$tmp"' EXIT
        fnox --no-daemon --non-interactive --if-missing error -c ${cfg.file} get ${lib.escapeShellArg name} \
          | base64 -d > "$tmp"
        chown ${lib.escapeShellArg "${secret.owner}:${secret.group}"} "$tmp"
        chmod ${secret.mode} "$tmp"
        mv -f "$tmp" ${lib.escapeShellArg secret.path}
      '';
      postStop = "rm -f ${lib.escapeShellArg secret.path}";
    }
  ) cfg.secrets;
}
