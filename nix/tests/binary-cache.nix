{ pkgs }:

let
  host = "prostagma.dropbear-tortoise.ts.net:8199";
  serverLanAddress = "192.168.1.2";
  serverTailnetAddress = "192.168.2.2";
  serverLanAddress6 = "2001:db8:1::2";
  serverTailnetAddress6 = "2001:db8:2::2";
  # A well-formed key that matches nothing, so Nix rejects the cache's signatures
  # until the test puts the key the running cache generated in its place.
  placeholderKey = "fleet:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  storePaths = pkgs.writeText "store-paths.nix" ''
    let
      generate = name: derivation {
        inherit name;
        system = "x86_64-linux";
        builder = "/bin/sh";
        args = [ "-c" "i=0; while [ $i -lt 20000 ]; do echo ''${name}-$i; i=$((i+1)); done > $out" ];
      };
    in
    {
      private = generate "private";
      upstream = generate "upstream";
      offline = generate "offline";
      rejected = generate "rejected";
    }
  '';
in
pkgs.testers.runNixOSTest {
  name = "binary-cache";

  nodes = {
    server = {
      imports = [
        ../machines/prostagma/app-storage.nix
        ../machines/prostagma/binary-cache.nix
      ];
      virtualisation = {
        vlans = [
          1
          2
        ];
        fileSystems."/srv/apps" = {
          device = "tmpfs";
          fsType = "tmpfs";
        };
      };
    };

    client = {
      imports = [ ../modules/binary-cache.nix ];
      dotfiles.binaryCache.publicKey = placeholderKey;
      virtualisation.vlans = [
        1
        2
      ];
      networking.hosts.${serverTailnetAddress} = [ "prostagma.dropbear-tortoise.ts.net" ];
      nix.settings = {
        experimental-features = [ "nix-command" ];
        # The build before the push would otherwise cache "not found" for an hour.
        narinfo-cache-negative-ttl = 0;
      };
      environment.etc."store-paths.nix".source = storePaths;
      environment.systemPackages = [ pkgs.attic-client ];
    };
  };

  testScript = ''
    import time

    url = "http://${host}"
    build = "nix-build --no-out-link /etc/store-paths.nix -A"
    substitute = "NIX_REMOTE=daemon nix-store --realise"
    chunks = "find /srv/apps/attic -type f ! -name VERSION"


    def narinfo(path):
        store_hash = path.removeprefix("/nix/store/").split("-")[0]
        return f"curl -sSf --max-time 5 {url}/fleet/{store_hash}.narinfo"


    # Each login uses the scope the runbook gives that step's token.
    def login(name, permissions, validity="1h"):
        token = server.succeed(f"atticd-atticadm make-token --sub {name} --validity {validity} {permissions}").strip()
        client.succeed(f"attic login {name} {url} {token}")


    def cache_key(name):
        info = client.succeed(f"attic cache info {name}:fleet 2>&1")
        return info.split("Public Key: ")[1].split()[0]


    def create_cache():
        login("setup", "--create-cache fleet --pull fleet")
        client.succeed(
            "attic cache create setup:fleet --public"
            " --upstream-cache-key-name cache.nixos.org-1"
            " --upstream-cache-key-name niks3.numtide.com-1"
            " --upstream-cache-key-name vicinae.cachix.org-1"
            " --upstream-cache-key-name nix-community.cachix.org-1"
        )
        return cache_key("setup")


    start_all()

    with subtest("the server starts without a pre-placed secret and keeps the one it made"):
        server.wait_for_unit("atticd.service")
        server.succeed("stat -c '%a %U %G' /var/lib/secrets/attic/environment | grep -qx '600 root root'")
        secret = server.succeed("sha256sum /var/lib/secrets/attic/environment")
        server.succeed("systemctl restart atticd.service")
        server.wait_for_unit("atticd.service")
        assert secret == server.succeed("sha256sum /var/lib/secrets/attic/environment")

    with subtest("a failed secret generation leaves no secret behind"):
        dropin = "/run/systemd/system/atticd-secret.service.d"
        server.succeed(
            "systemctl stop atticd.service",
            "rm /var/lib/secrets/attic/environment",
            "printf '#!/bin/sh\\nexit 1\\n' > /run/failing-openssl",
            "chmod +x /run/failing-openssl",
            f"mkdir -p {dropin}",
            f"printf '[Service]\\nBindReadOnlyPaths=/run/failing-openssl:${pkgs.lib.getExe pkgs.openssl}\\n' > {dropin}/fail.conf",
            "systemctl daemon-reload",
        )
        server.fail("systemctl start atticd-secret.service")
        server.succeed("test ! -e /var/lib/secrets/attic/environment")
        server.succeed(f"rm -r {dropin}", "systemctl daemon-reload", "systemctl start atticd.service")
        server.wait_for_unit("atticd.service")
        server.succeed("grep -q '^ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=.' /var/lib/secrets/attic/environment")

    with subtest("the server waits for app storage and keeps its data there"):
        server.succeed("systemctl show -p After --value atticd.service | grep -q prostagma-app-storage.service")
        server.succeed("stat -c '%U' /srv/apps/attic | grep -qx atticd")

    with subtest("only the tailnet interface reaches the server"):
        server.succeed(
            "ip link set eth2 down",
            "ip link set eth2 name tailscale0",
            "ip link set tailscale0 up",
            "ip address replace ${serverTailnetAddress}/24 dev tailscale0",
            "ip address replace ${serverTailnetAddress6}/64 dev tailscale0 nodad",
        )
        probe = "curl -sS --connect-timeout 3 -o /dev/null http://{}:8199/"
        client.wait_until_succeeds(probe.format("${serverTailnetAddress}"), timeout=60)
        client.wait_until_succeeds(probe.format("[${serverTailnetAddress6}]"), timeout=60)
        # 28 is curl's timeout: the firewall drops the connection, so any other
        # failure would mean the check proved nothing.
        for address in ["${serverLanAddress}", "[${serverLanAddress6}]"]:
            status, _ = client.execute(probe.format(address))
            assert status == 28, f"{address} gave curl exit {status}"
        client.succeed(f"curl -sS --max-time 5 -o /dev/null {url}/")

    with subtest("a cache can be created and a path pushed"):
        public_key = create_cache()
        login("ci", "--pull fleet --push fleet", validity="90d")
        private = client.succeed(f"{build} private").strip()
        client.succeed(f"attic push ci:fleet {private}")
        client.succeed(narinfo(private))
        server.succeed(f"{chunks} | grep -q .")

    with subtest("a push without a push token is rejected"):
        rejected = client.succeed(f"{build} rejected").strip()
        login("pull-only", "--pull fleet")
        client.succeed(f"attic login anonymous {url}")
        for name in ["anonymous", "pull-only"]:
            status, output = client.execute(f"attic push {name}:fleet {rejected} 2>&1")
            assert status != 0 and "User does not have permission" in output, output
        client.fail(narinfo(rejected))

    with subtest("a path signed by an upstream cache is not stored"):
        upstream = client.succeed(f"{build} upstream").strip()
        client.succeed(
            "nix-store --generate-binary-cache-key cache.nixos.org-1 /root/upstream.sk /root/upstream.pk",
            f"nix store sign --key-file /root/upstream.sk {upstream}",
            f"attic push ci:fleet {upstream}",
        )
        client.fail(narinfo(upstream))

    with subtest("substitution needs the cache's real key"):
        client.succeed(f"nix-store --delete {private}")
        status, output = client.execute(f"{substitute} {private} 2>&1")
        assert status != 0 and "not signed by" in output
        client.succeed(
            "cp --remove-destination $(readlink -f /etc/nix/nix.conf) /etc/nix/nix.conf",
            f"sed -i 's|${placeholderKey}|{public_key}|' /etc/nix/nix.conf",
            "systemctl restart nix-daemon.service",
        )
        client.succeed("nix config show stalled-download-timeout | grep -qx 30")
        client.succeed(f"{substitute} {private}")
        client.succeed(f"test -s {private}")
        assert "fleet:" in client.succeed(f"nix path-info --sigs {private}")

    with subtest("the size guard stops the cache once its storage passes the cap"):
        server.succeed("systemctl is-active atticd-size-guard.timer")
        server.succeed("systemctl start atticd-size-guard.service")
        server.succeed("systemctl is-active atticd.service")
        dropin = "/run/systemd/system/atticd-size-guard.service.d"
        server.succeed(
            f"mkdir -p {dropin}",
            f"printf '[Service]\\nEnvironment=CAP_BYTES=1024\\n' > {dropin}/cap.conf",
            "systemctl daemon-reload",
        )
        server.fail("systemctl start atticd-size-guard.service")
        server.fail("systemctl is-active atticd.service")
        server.succeed("systemctl is-failed atticd-size-guard.service")
        server.succeed("journalctl -u atticd-size-guard.service | grep -q 'Stopped atticd: /srv/apps/attic uses'")
        client.fail(narinfo(private))
        server.succeed(
            f"rm -r {dropin}",
            "systemctl daemon-reload",
            "systemctl start atticd.service",
            "systemctl start atticd-size-guard.service",
        )
        server.wait_for_unit("atticd.service")
        client.wait_until_succeeds(narinfo(private))

    with subtest("garbage collection removes an expired path"):
        login("retention", "--configure-cache fleet --configure-cache-retention fleet")
        client.succeed("attic cache configure retention:fleet --retention-period 1s")
        time.sleep(3)
        server.succeed("systemctl restart atticd.service")
        server.wait_for_unit("atticd.service")
        server.wait_until_succeeds(f"! {chunks} | grep -q .")
        client.fail(narinfo(private))

    with subtest("the runbook's wipe gives a working cache with a new key"):
        server.succeed(
            "systemctl stop atticd.service",
            "sudo -u postgres dropdb atticd",
            "sudo -u postgres createdb -O atticd atticd",
            "find /srv/apps/attic -mindepth 1 -delete",
            "systemctl start atticd.service",
        )
        server.wait_for_unit("atticd.service")
        client.wait_until_succeeds(f"curl -sS --max-time 5 -o /dev/null {url}/")
        assert create_cache() != public_key
        client.succeed(f"attic push ci:fleet {private}")
        client.succeed(narinfo(private))

    with subtest("the runbook's revocation invalidates the CI token"):
        secret = server.succeed("sha256sum /var/lib/secrets/attic/environment")
        server.succeed(
            "rm /var/lib/secrets/attic/environment",
            "systemctl restart atticd.service",
        )
        server.wait_for_unit("atticd.service")
        assert secret != server.succeed("sha256sum /var/lib/secrets/attic/environment")
        status, output = client.execute(f"attic push ci:fleet {rejected} 2>&1")
        assert status != 0 and "User does not have permission" in output, output
        client.fail(narinfo(rejected))
        login("ci", "--pull fleet --push fleet", validity="90d")
        client.succeed(f"attic push ci:fleet {rejected}")

    with subtest("an unreachable cache delays a build but does not break it"):
        client.succeed("iptables -I OUTPUT -d ${serverTailnetAddress} -j DROP")
        started = time.monotonic()
        client.succeed(f"NIX_REMOTE=daemon timeout 120 {build} offline")
        elapsed = time.monotonic() - started
        print(f"build with an unreachable cache took {elapsed:.0f}s")
        assert elapsed < 90
  '';
}
