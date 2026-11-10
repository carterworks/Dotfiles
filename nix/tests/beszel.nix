let
  inherit (import ../lib/fleet.nix) tailnetDomain;
  hubName = "beszel.${tailnetDomain}";
  # vlan 1 stands in for the tailnet, vlan 2 for the LAN.
  addresses = {
    prostagma = [
      "192.168.1.1"
      "192.168.2.1"
    ];
    scylla = [
      "192.168.1.2"
      "192.168.2.2"
    ];
  };
  hubTailnetAddress = builtins.head addresses.prostagma;
  # A well-formed key whose private half was thrown away, so every agent
  # rejects the hub until the test puts the key the running hub made in place.
  placeholderKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvlaMHWFtmQqctghQPLolJ2Vdaj50RhHJbiwjogIJOx";
  # The owner's Authelia account with a password known to the test.
  testPassword = "test-password";

  common =
    { pkgs, ... }:
    {
      imports = [ ../modules/nixos/beszel-agent.nix ];
      dotfiles.beszel.hubKey = placeholderKey;
      dotfiles.fnox.file = "/root/fnox.toml";
      virtualisation.vlans = [
        1
        2
      ];
      environment.systemPackages = [
        pkgs.age
        pkgs.curl
        pkgs.fnox
        pkgs.jq
        pkgs.openssh
        pkgs.openssl
      ];
    };
in
{
  name = "beszel";

  nodes = {
    prostagma =
      { lib, pkgs, ... }:
      {
        imports = [
          common
          ../hosts/prostagma/app-storage.nix
          ../hosts/prostagma/beszel.nix
          ../hosts/prostagma/sso.nix
        ];
        _module.args.fleet = import ../lib/fleet.nix;
        virtualisation.fileSystems."/srv/apps" = {
          device = "tmpfs";
          fsType = "tmpfs";
        };
        services.caddy.enable = true;

        # Tailscale Serve's part: forward the tailnet address to Caddy on loopback.
        systemd.services.serve-stand-in = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:80,bind=${hubTailnetAddress},fork,reuseaddr TCP:127.0.0.1:80";
            Restart = "on-failure";
          };
        };
        networking.firewall.interfaces.eth1.allowedTCPPorts = [ 80 ];

        services.authelia.instances.main.settings.authentication_backend.file.path = lib.mkForce (
          pkgs.writeText "authelia-test-users.yml" (
            builtins.toJSON {
              users.carter = {
                displayname = "Carter";
                password = "$argon2id$v=19$m=65536,t=3,p=4$Fryz0ithW78pc/O5zKXJFA$ZPwqGGM7DlE96n+hF3TClFgz0vXJNElq3GcV4ebTmfo";
                email = "carter@carter.works";
                groups = [ "admins" ];
              };
            }
          )
        );

        # Takes the hub's port while the hub is stopped and answers with the
        # request headers it received, to show what Caddy passes on.
        systemd.services.header-echo = {
          conflicts = [ "beszel-hub.service" ];
          serviceConfig.ExecStart = "${lib.getExe pkgs.python3} ${pkgs.writeText "header-echo.py" ''
            import http.server, json

            class Echo(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    body = json.dumps(dict(self.headers)).encode()
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(body)

            http.server.HTTPServer(("127.0.0.1", 8091), Echo).serve_forever()
          ''}";
        };
      };

    scylla =
      { lib, ... }:
      {
        imports = [ common ];
        # Serve terminates TLS on the real tailnet.
        services.beszel.agent.environment.HUB_URL = lib.mkForce "http://${hubName}";
        networking.hosts.${hubTailnetAddress} = [ hubName ];
      };
  };

  testScript = ''
    import json

    api = "http://127.0.0.1:8091/api"
    as_carter = "-H 'Remote-Email: carter@carter.works'"
    forged = "-H 'Remote-Email: intruder@example.com' -H 'Remote-User: intruder'"
    gate = "http://${hubName}"
    addresses = json.loads('${builtins.toJSON addresses}')


    def systems(header=as_carter):
        out = prostagma.succeed(f"curl -sSf {header} {api}/collections/systems/records")
        return {s["name"]: s["status"] for s in json.loads(out)["items"]}


    def login():
        """Authelia's first factor, as the portal's form sends it; returns the session cookie."""
        headers = prostagma.succeed(
            "curl -sS -D - -o /dev/null -H 'Host: authelia.${tailnetDomain}' -H 'X-Forwarded-Proto: https'"
            " --json '{\"username\":\"carter\",\"password\":\"${testPassword}\"}'"
            " http://127.0.0.1:9091/api/firstfactor"
        )
        cookie = [line for line in headers.splitlines() if line.lower().startswith("set-cookie: authelia_session=")]
        assert cookie, headers
        return cookie[0].split(":", 1)[1].split(";")[0].strip()


    def through_gate(path, args=""):
        """Status and body of a request from scylla through Serve and Caddy."""
        out = scylla.succeed(f"curl -sS -w '\\n%{{http_code}}' {args} {gate}{path}")
        body, status = out.rsplit("\n", 1)
        return int(status), body


    def echoed(path, args=""):
        status, body = through_gate(path, args)
        assert status == 200, (status, body)
        return {k.lower(): v for k, v in json.loads(body).items()}


    def records(collection, host):
        """The hub's records in a collection for one system."""
        systems = json.loads(prostagma.succeed(f"curl -sSf {as_carter} {api}/collections/systems/records"))["items"]
        system = next(s["id"] for s in systems if s["name"] == host)
        out = prostagma.succeed(
            f"curl -sSf -G {as_carter} --data-urlencode \"filter=system='{system}'\" -d perPage=500 {api}/collections/{collection}/records"
        )
        return json.loads(out)["items"]


    def listens_on_nothing():
        for machine in [prostagma, scylla]:
            pid = machine.succeed("systemctl show -P MainPID beszel-agent.service").strip()
            machine.fail(f"ss -Hltnup | grep -q 'pid={pid},'")
        for client, host in [(scylla, "prostagma"), (prostagma, "scylla")]:
            for address in addresses[host]:
                client.fail(f"curl -sS --max-time 5 telnet://{address}:45876 </dev/null")


    def use_key(machine, key):
        machine.succeed(
            "mkdir -p /run/systemd/system/beszel-agent.service.d",
            f"printf '[Service]\\nEnvironment=\"KEY={key}\"\\n' > /run/systemd/system/beszel-agent.service.d/key.conf",
            "systemctl daemon-reload",
            "systemctl restart beszel-agent.service",
        )


    start_all()
    prostagma.wait_for_unit("multi-user.target")
    scylla.wait_for_unit("multi-user.target")

    # The pipeline docs/monitoring.md gives the owner, with values made here.
    for machine in [prostagma, scylla]:
        machine.succeed("mkdir -p /etc/ssh && ssh-keygen -q -t ed25519 -N ''' -f /etc/ssh/ssh_host_ed25519_key")
    store_script = """
      set -euo pipefail
      cd /root
      export FNOX_CONFIG_DIR=/var/empty FNOX_AGE_KEY_FILE=/root/admin.txt
      age-keygen -o admin.txt 2>/dev/null
      admin=$(age-keygen -y admin.txt)
      prostagma=$(cat /etc/ssh/ssh_host_ed25519_key.pub)
      cat > fnox.toml <<EOF
    default_provider = "admin"
    [providers.admin]
    type = "age"
    recipients = ["$admin"]
    [providers.prostagma]
    type = "age"
    recipients = ["$admin", "$prostagma"]
    [providers.beszel-scylla]
    type = "age"
    recipients = ["$admin", "$prostagma", "SCYLLA_KEY"]
    EOF
      token() { openssl rand -hex 24 | tr -d '\\n' | base64 -w0 | fnox --no-daemon -c fnox.toml set "$1" -p "$2" >/dev/null; }
      token BESZEL_TOKEN_PROSTAGMA prostagma
      token BESZEL_TOKEN_ELTORO prostagma
      token BESZEL_TOKEN_SCYLLA beszel-scylla
      secret() { base64 -w0 | fnox --no-daemon -c fnox.toml set "$1" -p prostagma >/dev/null; }
      for name in JWT_SECRET SESSION_SECRET STORAGE_ENCRYPTION_KEY OIDC_HMAC_SECRET; do
        openssl rand -hex 32 | tr -d '\\n' | secret "AUTHELIA_$name"
      done
      openssl genrsa 2048 2>/dev/null | secret AUTHELIA_OIDC_ISSUER_PRIVATE_KEY
    """
    scylla_key = scylla.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
    prostagma.succeed(store_script.replace("SCYLLA_KEY", scylla_key))
    store = prostagma.succeed("cat /root/fnox.toml")
    scylla.succeed(f"cat > /root/fnox.toml <<'EOF'\n{store}EOF")
    # These failed at boot, before their secrets were in the store.
    for machine in [prostagma, scylla]:
        machine.succeed("systemctl restart beszel-agent.service")
    prostagma.succeed("systemctl restart authelia-main.service")
    prostagma.wait_for_open_port(9091, "127.0.0.1")

    with subtest("the hub starts on app storage, listening on loopback only"):
        prostagma.succeed("systemctl restart beszel-hub.service")
        prostagma.wait_for_unit("beszel-hub.service")
        prostagma.wait_for_open_port(8091, "127.0.0.1")
        prostagma.succeed("systemctl show -P After beszel-hub.service | grep -q prostagma-app-storage.service")
        prostagma.succeed("test -s /srv/apps/beszel-hub/beszel_data/id_ed25519")
        prostagma.succeed("stat -c %U /srv/apps/beszel-hub/beszel_data/data.db | grep -qx beszel-hub")
        for address in addresses["prostagma"]:
            scylla.fail(f"curl -sS --max-time 5 http://{address}:8091/")

    with subtest("the proxy's header is the only way in"):
        assert set(systems()) == {"prostagma", "scylla", "eltoro"}, systems()
        assert systems(header="") == {}, "the hub showed systems without a login"
        methods = json.loads(prostagma.succeed(f"curl -sSf {api}/collections/users/auth-methods"))
        assert not methods["password"]["enabled"], methods

    # Any local process on prostagma that can reach the hub's port with this
    # header is the owner; nothing but the loopback binding keeps others out.
    with subtest("on prostagma, the header alone logs in at the hub's own port"):
        me = json.loads(prostagma.succeed(f"curl -sSf -X POST {as_carter} {api}/collections/users/auth-refresh"))
        assert me["record"]["email"] == "carter@carter.works", me

    session = f"-H 'Cookie: {login()}'"

    with subtest("a logged-in owner reaches the hub through the gate"):
        status, body = through_gate("/api/collections/systems/records", session)
        assert status == 200, (status, body)
        names = {s["name"] for s in json.loads(body)["items"]}
        assert names == {"prostagma", "scylla", "eltoro"}, names

    with subtest("without a session the gate refuses, forged header or not"):
        for args in ["", forged, as_carter]:
            status, body = through_gate("/api/collections/systems/records", args)
            assert status in (302, 401), (args, status, body)
            assert "prostagma" not in body, body

    with subtest("the agents' path bypasses the gate and the hub refuses a wrong token"):
        status, body = through_gate("/api/beszel/agent-connect", f"{forged} -H 'X-Token: wrong' -H 'X-Beszel: 0.21.1'")
        assert (status, body) == (401, "Invalid token"), (status, body)

    with subtest("Caddy passes on Authelia's identity and never a client's"):
        prostagma.succeed("systemctl start header-echo.service")
        prostagma.wait_for_open_port(8091, "127.0.0.1")
        gated = echoed("/api/collections/systems/records", f"{session} {forged}")
        assert gated.get("remote-email") == "carter@carter.works", gated
        assert gated.get("remote-user") == "carter", gated
        bypass = echoed("/api/beszel/agent-connect", forged)
        assert not any(k.startswith("remote-") for k in bypass), bypass
        prostagma.succeed("systemctl start beszel-hub.service")
        prostagma.wait_for_open_port(8091, "127.0.0.1")

    with subtest("an agent refuses a hub whose key it does not have"):
        scylla.wait_until_succeeds("journalctl -u beszel-agent | grep -q 'invalid signature - check KEY value'", timeout=60)
        assert systems()["scylla"] != "up"

    # A disconnected agent would start its SSH fallback, so check both states.
    with subtest("a disconnected agent listens on nothing"):
        listens_on_nothing()

    with subtest("with the hub's key, both agents connect and the hub records them"):
        key = json.loads(prostagma.succeed(f"curl -sSf {as_carter} {api}/beszel/info"))["key"]
        use_key(prostagma, key)
        use_key(scylla, key)
        prostagma.wait_until_succeeds(
            f"curl -sSf {as_carter} {api}/collections/systems/records"
            " | jq -e '[.items[] | select(.status == \"up\") | .name] | sort == [\"prostagma\", \"scylla\"]'",
            timeout=120,
        )
        assert systems()["eltoro"] != "up"

    with subtest("prostagma's agent reports its services but cannot read the journal"):
        prostagma.wait_until_succeeds(
            f"curl -sSf {as_carter} {api}/collections/systems/records"
            " | jq -e '[.items[] | select(.name == \"prostagma\")][0].info.sv != null'",
            timeout=180,
        )
        names = {r["name"] for r in records("systemd_services", "prostagma")}
        assert {"caddy", "authelia-main"} <= names, names
        groups = prostagma.succeed("systemctl show -P SupplementaryGroups beszel-agent.service").split()
        assert "systemd-journal" not in groups, groups
        system = next(s for s in json.loads(prostagma.succeed(f"curl -sSf {as_carter} {api}/collections/systems/records"))["items"] if s["name"] == "prostagma")
        assert not system["info"].get("jl"), system["info"]

    with subtest("the owner's account is read-only, cannot read tokens and still sets alerts"):
        me = json.loads(prostagma.succeed(f"curl -sSf -X POST {as_carter} {api}/collections/users/auth-refresh"))["record"]
        assert me["role"] == "readonly", me
        fingerprints = json.loads(prostagma.succeed(f"curl -sSf {as_carter} -d perPage=500 -G {api}/collections/fingerprints/records"))
        assert fingerprints["items"] == [], fingerprints
        status = prostagma.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' -X POST {as_carter} {api}/beszel/universal-token")
        assert status == "403", status
        system = next(s["id"] for s in json.loads(prostagma.succeed(f"curl -sSf {as_carter} {api}/collections/systems/records"))["items"] if s["name"] == "prostagma")
        alert = {"user": me["id"], "system": system, "name": "CPU", "value": 80, "min": 10}
        prostagma.succeed(f"curl -sSf {as_carter} --json '{json.dumps(alert)}' {api}/collections/alerts/records")
        assert len(records("alerts", "prostagma")) == 1

    with subtest("a connected agent listens on nothing"):
        listens_on_nothing()

    with subtest("no agent token reaches Caddy's logs or the journal"):
        # An upstream error makes Caddy log the request, headers and all.
        prostagma.succeed("systemctl stop beszel-hub.service", "journalctl --rotate")
        scylla.succeed("systemctl restart beszel-agent.service")
        prostagma.wait_until_succeeds("journalctl -u caddy | grep -q 'dial tcp 127.0.0.1:8091'", timeout=60)
        prostagma.succeed("systemctl start beszel-hub.service")
        prostagma.wait_until_succeeds(
            f"curl -sSf {as_carter} {api}/collections/systems/records"
            " | jq -e '[.items[] | select(.name == \"scylla\")][0].status == \"up\"'",
            timeout=120,
        )
        prostagma.succeed("grep -q agent-connect /var/log/caddy/access-*beszel*")
        for host in ["prostagma", "scylla", "eltoro"]:
            token = prostagma.succeed(f"cat /run/secrets/beszel/{host}-token").strip()
            prostagma.fail(f"grep -rqF {token} /var/log/caddy")
            for machine in [prostagma, scylla]:
                machine.fail(f"journalctl -o cat | grep -qF {token}")
  '';
}
