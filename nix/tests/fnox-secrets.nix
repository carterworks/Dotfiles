let
  # A recognisable dummy value, generated inside the VM at run time.
  marker = "fnox-test-marker-5b0e3c";

  # Each consumer records what it saw at the moment it started.
  consumer =
    { path, user }:
    {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        RuntimeDirectory = "%N";
        # The secret directories are root-only; a non-root service reaches its
        # file the way copyparty does on prostagma, in an empty root that only
        # the bound paths populate.
        TemporaryFileSystem = "/:ro";
        BindReadOnlyPaths = [
          "/nix/store"
          "/etc/passwd"
          "/etc/group"
          path
        ];
      };
      script = ''
        stat -c '%U %G %a' ${path} > "$RUNTIME_DIRECTORY/stat"
        cat ${path} > "$RUNTIME_DIRECTORY/seen"
      '';
    };
in
{
  name = "fnox-secrets";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../modules/nixos/secrets.nix ];

      environment.systemPackages = [
        pkgs.age
        pkgs.fnox
        pkgs.openssh
      ];

      users.users.app = {
        isSystemUser = true;
        group = "app";
      };
      users.groups.app = { };

      dotfiles.fnox = {
        file = "/root/fnox.toml";
        secrets = {
          TRAILING = {
            path = "/run/secrets/trailing";
            owner = "app";
            group = "app";
            mode = "0440";
            requiredBy = [ "consumer-trailing.service" ];
          };
          PEM = {
            path = "/run/secrets/nested/key.pem";
            requiredBy = [ "consumer-pem.service" ];
          };
          BINARY = {
            path = "/run/secrets/binary";
            mode = "0600";
            requiredBy = [ "consumer-binary.service" ];
          };
          FOREIGN = {
            path = "/run/secrets/foreign";
            requiredBy = [ "consumer-foreign.service" ];
          };
          ABSENT = {
            path = "/run/secrets/absent";
            requiredBy = [ "consumer-absent.service" ];
          };
        };
      };

      systemd.services = {
        consumer-trailing = consumer {
          path = "/run/secrets/trailing";
          user = "app";
        };
        consumer-pem = consumer {
          path = "/run/secrets/nested/key.pem";
          user = "root";
        };
        consumer-binary = consumer {
          path = "/run/secrets/binary";
          user = "root";
        };
        consumer-foreign = consumer {
          path = "/run/secrets/foreign";
          user = "root";
        };
        consumer-absent = consumer {
          path = "/run/secrets/absent";
          user = "root";
        };
      };
    };

  testScript = ''
    expected = {
        "trailing": ("/run/secrets/trailing", "app app 440"),
        "pem": ("/run/secrets/nested/key.pem", "root root 400"),
        "binary": ("/run/secrets/binary", "root root 600"),
    }

    def started(unit):
        return int(machine.succeed(f"systemctl show -P ExecMainStartTimestampMonotonic {unit}"))

    machine.wait_for_unit("multi-user.target")

    # The same pipeline docs/secrets.md uses to import a value.
    machine.succeed("""
      set -euo pipefail
      cd /root
      export FNOX_CONFIG_DIR=/var/empty FNOX_AGE_KEY_FILE=/root/admin.txt
      age-keygen -o admin.txt 2>/dev/null
      mkdir -p /etc/ssh
      ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
      ssh-keygen -q -t ed25519 -N "" -f other
      cat > fnox.toml <<EOF
    default_provider = "admin"
    [providers.admin]
    type = "age"
    recipients = ["$(age-keygen -y admin.txt)"]
    [providers.machine]
    type = "age"
    recipients = ["$(age-keygen -y admin.txt)", "$(cat /etc/ssh/ssh_host_ed25519_key.pub)"]
    [providers.other]
    type = "age"
    recipients = ["$(age-keygen -y admin.txt)", "$(cat other.pub)"]
    EOF
      printf '${marker}\\n' > trailing
      printf -- '-----BEGIN TEST KEY-----\\nMIIB${marker}\\n  indented line\\n-----END TEST KEY-----\\n\\n' > pem
      { printf '\\0\\r\\n \\t'; head -c 4096 /dev/urandom; printf '\\n\\0\\n\\n'; } > binary
      for name in trailing pem binary; do
        base64 -w0 "$name" | fnox --no-daemon -c /root/fnox.toml set "''${name^^}" -p machine
      done
      base64 -w0 trailing | fnox --no-daemon -c /root/fnox.toml set FOREIGN -p other
    """)

    # Left behind world-readable, as by an earlier generation or by hand: the
    # module must tighten them, not just create what is missing.
    machine.succeed("install -d -m 0777 /run/secrets /run/secrets/nested")

    with subtest("each value reaches its file with its owner and mode before its consumer starts"):
        machine.succeed("systemctl start consumer-trailing consumer-pem consumer-binary")
        for name, (path, stat) in expected.items():
            unit = f"fnox-secret-{name.upper()}"
            seen = machine.succeed(f"cat /run/consumer-{name}/stat").strip()
            assert seen == stat, f"{name}: consumer saw {seen!r}, expected {stat!r}"
            assert machine.succeed(f"systemctl show -P After consumer-{name}").count(f"{unit}.service") == 1
            ready = int(machine.succeed(f"systemctl show -P ActiveEnterTimestampMonotonic {unit}"))
            assert 0 < ready <= started(f"consumer-{name}"), f"{name}: consumer started before its secret"

    with subtest("values arrive byte for byte"):
        for name, (path, _) in expected.items():
            machine.succeed(f"cmp /root/{name} {path}", f"cmp /root/{name} /run/consumer-{name}/seen")

    with subtest("the secret directories are root-only"):
        modes = machine.succeed("stat -c %a /run/secrets /run/secrets/nested").split()
        assert modes == ["700", "700"], f"secret directories are {modes}"
        machine.fail("runuser -u app -- cat /run/secrets/trailing")

    with subtest("a host cannot decrypt a secret not addressed to it"):
        machine.fail("systemctl start consumer-foreign")
        machine.succeed("journalctl -u fnox-secret-FOREIGN | grep -q 'No matching keys'")
        machine.succeed("test ! -e /run/secrets/foreign")
        assert started("consumer-foreign") == 0
        # It is a valid secret all the same: its own recipients can read it.
        machine.succeed("FNOX_CONFIG_DIR=/var/empty FNOX_AGE_KEY_FILE=/root/other fnox --no-daemon -c /root/fnox.toml get FOREIGN | base64 -d | cmp - /root/trailing")

    with subtest("a secret missing from the store fails its consumer and nothing else"):
        machine.fail("systemctl start consumer-absent")
        assert started("consumer-absent") == 0
        machine.succeed("systemctl is-active consumer-trailing consumer-pem consumer-binary")

    with subtest("a missing host key fails the dependent service and nothing else"):
        machine.succeed("mv /etc/ssh/ssh_host_ed25519_key /root/host_key")
        machine.fail("systemctl restart fnox-secret-PEM")
        machine.succeed("journalctl -u fnox-secret-PEM | grep -q 'Failed to read age identity file'")
        machine.fail("systemctl is-active consumer-pem")
        machine.succeed("test ! -e /run/secrets/nested/key.pem")
        machine.succeed("systemctl is-active consumer-trailing consumer-binary")
        machine.succeed("cmp /root/trailing /run/secrets/trailing", "cmp /root/binary /run/secrets/binary")
        machine.succeed("mv /root/host_key /etc/ssh/ssh_host_ed25519_key")
        machine.succeed("systemctl start consumer-pem", "cmp /root/pem /run/consumer-pem/seen")
  '';
}
