let
  internetIp4 = "192.168.1.2";
  internetIp6 = "2001:db8:1::2";
  eltoroIp4 = "192.168.1.1";
  unlisted = "203.0.113.10";
  # Inside egressAllowedCidrs.
  allowedCidr = "151.101.1.1";
  # Only reachable because the refresh service resolves an allowlisted domain to it.
  allowedDns = "198.51.100.7";
  peerIp4 = "100.64.0.2";
  peerIp6 = "fd7a:115c:a1e0::2";
  magicDns = "100.100.100.100";

  listen = pkgs: spec: {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''${pkgs.socat}/bin/socat ${spec},fork,reuseaddr "SYSTEM:echo ok"'';
  };
in
{
  name = "eltoro-egress";

  nodes.eltoro =
    { lib, pkgs, ... }:
    {
      imports = [ ../machines/eltoro/egress.nix ];
      eltoro.egress.uplink = "eth1";

      users.groups.hermes = { };
      users.users.hermes = {
        isSystemUser = true;
        group = "hermes";
      };
      systemd.services.hermes-inbound = listen pkgs "TCP6-LISTEN:9119" // {
        serviceConfig = (listen pkgs "TCP6-LISTEN:9119").serviceConfig // {
          User = "hermes";
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ 9119 ];
        trustedInterfaces = [ "tailscale0" ];
      };
      networking.defaultGateway = {
        address = internetIp4;
        interface = "eth1";
      };
      # The VM has no DNS, but getent consults /etc/hosts, which drives the
      # same refresh path a real answer would.
      networking.hosts.${allowedDns} = [ "discord.com" ];

      # Puts itself in front of iptables and ip6tables on PATH and records any
      # call after which neither the chain nor the catch-all is hooked.
      environment.etc = lib.genAttrs [ "fence-probe/iptables" "fence-probe/ip6tables" ] (_: {
        mode = "0755";
        source = pkgs.writeShellScript "fence-probe" ''
          /run/current-system/sw/bin/''${0##*/} "$@"
          rc=$?
          for ipt in iptables ip6tables; do
            /run/current-system/sw/bin/$ipt -w -S OUTPUT | grep -Eq -- '-j hermes-egress(-closed)?$' ||
              echo "$ipt unfenced after ''${0##*/} $*" >>/tmp/unfenced
          done
          exit $rc
        '';
      });

      environment.systemPackages = [
        pkgs.ipset
        pkgs.iptables
        pkgs.socat
      ];
    };

  nodes.internet =
    { pkgs, ... }:
    {
      networking.firewall.enable = false;
      systemd.services.listener = listen pkgs "TCP6-LISTEN:80";
      environment.systemPackages = [ pkgs.socat ];
    };

  testScript = ''
    import re


    def connect(user, proto, target):
        return eltoro.execute(
            f"echo hi | timeout 8 runuser -u {user} -- socat -t2 -T3 - {proto}:{target}",
            timeout=30,
        )


    def allowed(user, proto, target):
        status, output = connect(user, proto, target)
        assert status == 0 and "ok" in output, f"{user} should reach {target}: {status} {output!r}"


    def blocked(user, proto, target):
        status, output = connect(user, proto, target)
        assert status != 0, f"{user} should not reach {target}: {output!r}"


    def assert_inbound_replies():
        for reply in (
            eltoro.succeed("echo hi | ip netns exec peer socat -t2 -T3 - TCP4:100.64.0.1:9119"),
            eltoro.succeed("echo hi | ip netns exec peer socat -t2 -T3 - 'TCP6:[fd7a:115c:a1e0::1]:9119'"),
            internet.succeed("echo hi | socat -t2 -T3 - TCP4:${eltoroIp4}:9119"),
        ):
            assert "ok" in reply


    def assert_fence():
        blocked("hermes", "TCP4", "${unlisted}:80")
        allowed("root", "TCP4", "${unlisted}:80")
        blocked("hermes", "TCP4", "${internetIp4}:80")
        allowed("hermes", "TCP4", "${allowedCidr}:80")
        allowed("hermes", "TCP4", "${allowedDns}:80")

        blocked("hermes", "TCP6", "[${internetIp6}]:80")
        allowed("root", "TCP6", "[${internetIp6}]:80")

        blocked("hermes", "TCP4", "${peerIp4}:80")
        allowed("root", "TCP4", "${peerIp4}:80")
        blocked("hermes", "TCP6", "[${peerIp6}]:80")
        # Unlike IPv4, the IPv6 tailnet rule has no uid exemption.
        blocked("root", "TCP6", "[${peerIp6}]:80")

        # Users other than hermes are as unrestricted as root.
        allowed("nobody", "TCP4", "${unlisted}:80")
        allowed("nobody", "TCP6", "[${internetIp6}]:80")
        allowed("nobody", "TCP4", "${peerIp4}:80")
        blocked("nobody", "TCP6", "[${peerIp6}]:80")
        allowed("nobody", "TCP4", "${magicDns}:5300")

        allowed("hermes", "TCP4", "${magicDns}:53")
        allowed("hermes", "UDP4", "${magicDns}:53")
        blocked("hermes", "TCP4", "${magicDns}:5300")
        allowed("root", "TCP4", "${magicDns}:5300")

        assert_inbound_replies()


    def output_rules(save):
        return eltoro.execute(f"{save} -t filter | grep -E '^-A (OUTPUT|hermes-egress) '")[1].splitlines()


    def assert_rules_once():
        for save, count in (("iptables-save", 10), ("ip6tables-save", 5)):
            rules = output_rules(save)
            assert len(rules) == count, f"{save}: expected {count} rules, got {rules}"
            assert len(set(rules)) == count, f"{save}: duplicate rules in {rules}"


    def assert_closed():
        blocked("hermes", "TCP4", "${allowedCidr}:80")
        blocked("hermes", "TCP4", "${unlisted}:80")
        blocked("hermes", "TCP6", "[${internetIp6}]:80")
        blocked("hermes", "TCP4", "${peerIp4}:80")
        blocked("hermes", "UDP4", "${magicDns}:53")
        allowed("root", "TCP4", "${unlisted}:80")
        allowed("root", "TCP6", "[${internetIp6}]:80")
        allowed("root", "TCP4", "${peerIp4}:80")
        assert_inbound_replies()
        for save in ("iptables-save", "ip6tables-save"):
            hooks = [rule for rule in output_rules(save) if rule.startswith("-A OUTPUT ")]
            assert hooks == ["-A OUTPUT -j hermes-egress-closed"], f"{save}: {hooks}"


    def unit_script(prop, probe=False):
        show = eltoro.succeed(f"systemctl show firewall -p {prop}")
        match = re.search(r"path=(\S+)", show)
        assert match, show
        path = "PATH=/etc/fence-probe:$PATH " if probe else ""
        eltoro.succeed(path + match.group(1))


    def peer_listener(unit, spec):
        return f"systemd-run --unit={unit} -E PATH ip netns exec peer socat {spec},fork 'SYSTEM:echo ok'"


    start_all()
    internet.wait_for_unit("multi-user.target")
    eltoro.wait_for_unit("multi-user.target")
    eltoro.wait_for_unit("firewall.service")

    internet.succeed(
        "ip addr add ${unlisted}/32 dev lo",
        "ip addr add ${allowedCidr}/32 dev lo",
        "ip addr add ${allowedDns}/32 dev lo",
    )

    # A veth into a namespace stands in for Tailscale: unlike a dummy interface,
    # the far end answers, so a permitted connection really completes.
    eltoro.succeed(
        "ip netns add peer",
        "ip link add tailscale0 type veth peer name peer0",
        "ip link set peer0 netns peer",
        "ip addr add 100.64.0.1/10 dev tailscale0",
        "ip -6 addr add fd7a:115c:a1e0::1/48 dev tailscale0 nodad",
        "ip link set tailscale0 up",
        "ip -n peer link set lo up",
        "ip -n peer addr add ${peerIp4}/10 dev peer0",
        "ip -n peer addr add ${magicDns}/32 dev peer0",
        "ip -n peer -6 addr add ${peerIp6}/48 dev peer0 nodad",
        "ip -n peer link set peer0 up",
        # The real tailscale0 is a layer-3 tun with no neighbour discovery; on a
        # veth the IPv6 tailnet REJECT would eat eltoro's neighbour advertisements.
        "ip -n peer -6 neigh replace fd7a:115c:a1e0::1 lladdr $(cat /sys/class/net/tailscale0/address) dev peer0 nud permanent",
        peer_listener("peer-80", "TCP6-LISTEN:80,reuseaddr"),
        peer_listener("peer-53", "TCP4-LISTEN:53,reuseaddr"),
        peer_listener("peer-53u", "UDP4-RECVFROM:53,bind=${magicDns}"),
        peer_listener("peer-5300", "TCP4-LISTEN:5300,reuseaddr"),
    )
    eltoro.wait_until_succeeds("test $(ip netns exec peer ss -Hlntu | wc -l) = 4")
    eltoro.wait_for_open_port(9119)
    internet.wait_for_open_port(80)

    eltoro.succeed("systemctl start egress-allowlist")

    with subtest("fence holds after boot"):
        assert_rules_once()
        assert_fence()

    with subtest("reload keeps exactly one copy of the rules"):
        eltoro.succeed("systemctl reload firewall")
        assert_rules_once()
        assert_fence()

    with subtest("restart keeps exactly one copy of the rules"):
        eltoro.succeed("systemctl restart firewall")
        assert_rules_once()
        assert_fence()

    with subtest("stop leaves hermes fenced and start restores the chain"):
        eltoro.succeed("systemctl stop firewall")
        assert_closed()
        eltoro.succeed("systemctl start firewall")
        assert_rules_once()
        assert_fence()

    with subtest("no rule survives from an earlier generation"):
        # The stale-uid incident: an old generation's rule, for a uid the current
        # delete commands would no longer match.
        for ipt in ("iptables", "ip6tables"):
            eltoro.succeed(f"{ipt} -w -A OUTPUT -o eth1 -m owner ! --uid-owner 1234 -j ACCEPT")
        eltoro.succeed("systemctl reload firewall")
        assert_rules_once()
        assert_fence()

    with subtest("a switch from the generation before the chain leaves only the chain"):
        for ipt in ("iptables", "ip6tables"):
            eltoro.succeed(f"{ipt} -w -D OUTPUT -j hermes-egress", f"{ipt} -w -F hermes-egress", f"{ipt} -w -X hermes-egress")
        # Verbatim from that generation's extraCommands, with eth1 for its eth0.
        eltoro.succeed(
            "iptables  -w -A OUTPUT -o tailscale0 -d 100.64.0.0/10 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT",
            "iptables  -w -A OUTPUT -o tailscale0 -m owner ! --uid-owner hermes -j ACCEPT",
            "iptables  -w -A OUTPUT -o tailscale0 -d 100.100.100.100 -p udp -m udp --dport 53 -j ACCEPT",
            "iptables  -w -A OUTPUT -o tailscale0 -d 100.100.100.100 -p tcp -m tcp --dport 53 -j ACCEPT",
            "iptables  -w -A OUTPUT -o tailscale0 -d 100.64.0.0/10 -j REJECT --reject-with icmp-admin-prohibited",
            "ip6tables -w -A OUTPUT -o tailscale0 -d fd7a:115c:a1e0::/48 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT",
            "ip6tables -w -A OUTPUT -o tailscale0 -d fd7a:115c:a1e0::/48 -j REJECT --reject-with icmp6-adm-prohibited",
            "iptables  -w -A OUTPUT -o eth1 -m owner ! --uid-owner hermes -j ACCEPT",
            "iptables  -w -A OUTPUT -o eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT",
            "iptables  -w -A OUTPUT -o eth1 -m set --match-set egress-allowed dst -j ACCEPT",
            "iptables  -w -A OUTPUT -o eth1 -m owner --uid-owner hermes -j REJECT --reject-with icmp-admin-prohibited",
            "ip6tables -w -A OUTPUT -o eth1 -m owner ! --uid-owner hermes -j ACCEPT",
            "ip6tables -w -A OUTPUT -o eth1 -m owner --uid-owner hermes -j REJECT --reject-with icmp6-adm-prohibited",
        )
        eltoro.succeed("systemctl reload firewall")
        for save in ("iptables-save", "ip6tables-save"):
            hooks = [rule for rule in output_rules(save) if rule.startswith("-A OUTPUT ")]
            assert hooks == ["-A OUTPUT -j hermes-egress"], f"{save}: {hooks}"
        assert_rules_once()
        assert_fence()

    with subtest("an empty allowlist lets hermes reach nothing on the uplink"):
        eltoro.succeed("systemctl stop egress-allowlist.timer", "ipset flush egress-allowed")
        blocked("hermes", "TCP4", "${allowedDns}:80")
        blocked("hermes", "TCP4", "${allowedCidr}:80")
        allowed("root", "TCP4", "${allowedDns}:80")
        # The set as a fresh start creates it, before any refresh has run.
        eltoro.succeed("systemctl stop firewall", "ipset destroy egress-allowed", "systemctl start firewall")
        blocked("hermes", "TCP4", "${allowedDns}:80")
        blocked("hermes", "TCP4", "${allowedCidr}:80")
        eltoro.succeed("systemctl start egress-allowlist egress-allowlist.timer")
        assert_fence()

    with subtest("start and stop are idempotent"):
        unit_script("ExecStop")
        unit_script("ExecStop")
        assert_closed()
        unit_script("ExecStart")
        unit_script("ExecStart")
        assert_rules_once()
        assert_fence()

    with subtest("a failed reload leaves hermes fenced"):
        # Referencing a chain from elsewhere makes the start script fail to
        # recreate it: nixos-fw-accept fails before extraCommands, hermes-egress
        # within it.
        for target in ("nixos-fw-accept", "hermes-egress"):
            for ipt in ("iptables", "ip6tables"):
                eltoro.succeed(f"{ipt} -w -N sabotage", f"{ipt} -w -A sabotage -j {target}")
            eltoro.fail("systemctl reload firewall")
            eltoro.succeed("systemctl is-active firewall")
            assert_closed()
            for ipt in ("iptables", "ip6tables"):
                eltoro.succeed(f"{ipt} -w -F sabotage", f"{ipt} -w -X sabotage")
            eltoro.succeed("systemctl reload firewall")
            assert_rules_once()
            assert_fence()

    with subtest("no moment without a fence"):
        for prop in ("ExecStart", "ExecReload", "ExecStop", "ExecStart"):
            unit_script(prop, probe=True)
        eltoro.fail("cat /tmp/unfenced")
        assert_rules_once()
        assert_fence()
  '';
}
