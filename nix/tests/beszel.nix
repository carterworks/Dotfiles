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
      { pkgs, ... }:
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
    addresses = json.loads('${builtins.toJSON addresses}')


    def systems(header=as_carter):
        out = prostagma.succeed(f"curl -sSf {header} {api}/collections/systems/records")
        return {s["name"]: s["status"] for s in json.loads(out)["items"]}


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
    """
    scylla_key = scylla.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
    prostagma.succeed(store_script.replace("SCYLLA_KEY", scylla_key))
    store = prostagma.succeed("cat /root/fnox.toml")
    scylla.succeed(f"cat > /root/fnox.toml <<'EOF'\n{store}EOF")
    # Both failed at boot, before their tokens were in the store.
    for machine in [prostagma, scylla]:
        machine.succeed("systemctl restart beszel-agent.service")

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

    with subtest("through the gate, a client's own header does not log it in"):
        out = scylla.succeed(f"curl -s {as_carter} http://${hubName}/api/collections/systems/records")
        assert "prostagma" not in out, f"a spoofed header logged in: {out}"

    with subtest("the agents' path bypasses the gate and the hub refuses a wrong token"):
        out = scylla.succeed(
            "curl -s -w ' %{http_code}' -H 'X-Token: wrong' -H 'X-Beszel: 0.21.1' http://${hubName}/api/beszel/agent-connect"
        )
        assert out == "Invalid token 401", out

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

    with subtest("a connected agent listens on nothing"):
        listens_on_nothing()
  '';
}
