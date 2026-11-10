let
  internetIp4 = "192.168.1.2";
  internetIp6 = "2001:db8:1::2";
  eltoroIp4 = "192.168.1.1";
  eltoroIp6 = "2001:db8:1::1";
  unlisted = "203.0.113.10";
  # Inside egressAllowedCidrs.
  allowedCidr = "151.101.1.1";
  # Only reachable because the refresh service resolves an allowlisted domain to it.
  allowedDns = "198.51.100.7";
  peerIp4 = "100.64.0.2";
  peerIp6 = "fd7a:115c:a1e0::2";
  magicDns = "100.100.100.100";
  # Behind a subnet router or exit node on tailscale0, outside the tailnet ranges.
  routedIp4 = "198.18.0.1";
  routedIp6 = "2001:db8:99::1";
  # On a second NIC.
  lanIp4 = "10.99.0.2";
  lanIp6 = "fd00:99::2";
  # Of the file the internet node serves over HTTP.
  okHash = "sha256-3FG4yWwtdF3zvVWQ2ZAjCkgv0kcSNZlUjgYy/b+X/CI=";

  listen = pkgs: spec: {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''${pkgs.socat}/bin/socat ${spec},fork,reuseaddr "SYSTEM:echo ok"'';
  };
in
{
  name = "eltoro-egress";

  nodes.eltoro =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      fenceProbe = {
        mode = "0755";
        source = pkgs.writeShellScript "fence-probe" ''
          /run/current-system/sw/bin/''${0##*/} "$@"
          rc=$?
          echo >>/tmp/probe-runs
          for ipt in iptables ip6tables; do
            fenced=
            for target in $(/run/current-system/sw/bin/$ipt -w -S OUTPUT | sed -n 's/^-A OUTPUT -j \(hermes-egress\(-closed\)\?\)$/\1/p'); do
              /run/current-system/sw/bin/$ipt -w -S "$target" | grep -q -- '-j REJECT' && fenced=1
            done
            [ -n "$fenced" ] || echo "$ipt unfenced after ''${0##*/} $*" >>/tmp/unfenced
          done
          exit $rc
        '';
      };
    in
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
      # Stands in for the Hermes units, which gate their start the same way.
      systemd.services.fenced = {
        serviceConfig = {
          Type = "oneshot";
          User = "hermes";
          ExecStartPre = "+${config.eltoro.egress.checkHooked}";
          ExecStart = "${pkgs.coreutils}/bin/true";
        };
      };

      # As on eltoro, the dashboard port is open over the tailnet only.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      networking.defaultGateway = {
        address = internetIp4;
        interface = "eth1";
      };
      # The VM has no DNS, but getent consults /etc/hosts, which drives the
      # same refresh path a real answer would.
      networking.hosts.${allowedDns} = [ "discord.com" ];

      # Puts itself in front of iptables and ip6tables on PATH, counts its
      # calls so the test knows it ran, and records any call after which no
      # chain hooked into OUTPUT, the main one or the catch-all, rejects.
      environment.etc."fence-probe/iptables" = fenceProbe;
      environment.etc."fence-probe/ip6tables" = fenceProbe;

      # A fixed-output derivation gets the host's network. This one reports
      # what its builder could reach, then fails so it never gets cached.
      environment.etc."fod-escape.nix".text = ''
        derivation {
          name = "fod-escape";
          system = "${pkgs.stdenv.hostPlatform.system}";
          builder = builtins.storePath "${pkgs.busybox}/bin/busybox";
          args = [ "sh" "-c" "echo allowed:$(${pkgs.busybox}/bin/nc -w 3 ${allowedCidr} 80 </dev/null) unlisted:$(${pkgs.busybox}/bin/nc -w 3 ${unlisted} 80 </dev/null); exit 1" ];
          outputHashMode = "flat";
          outputHashAlgo = "sha256";
          outputHash = "0000000000000000000000000000000000000000000000000000";
        }
      '';
      # Nix runs builtin:fetchurl itself rather than exec'ing a builder, so it
      # needs its own proof that the fetch happens as a build user.
      environment.etc."builtin-fetch.nix".text = ''
        { host }:
        import <nix/fetchurl.nix> {
          name = "builtin-fetch-''${builtins.replaceStrings [ "." ] [ "-" ] host}";
          url = "http://''${host}:8080/ok";
          hash = "${okHash}";
        }
      '';
      system.extraDependencies = [ pkgs.busybox ];
      nix.settings.substituters = lib.mkForce [ ];

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
      systemd.services.http = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080 -d ${pkgs.writeTextDir "ok" "ok\n"}";
      };
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


    def pings(user, target):
        return eltoro.execute(f"runuser -u {user} -- ping -c1 -W2 {target}")[0] == 0


    def assert_inbound_replies():
        for reply in (
            eltoro.succeed("echo hi | ip netns exec peer socat -t2 -T3 - TCP4:100.64.0.1:9119"),
            eltoro.succeed("echo hi | ip netns exec peer socat -t2 -T3 - 'TCP6:[fd7a:115c:a1e0::1]:9119'"),
        ):
            assert "ok" in reply


    uplink_dashboard = ("TCP4:${eltoroIp4}:9119", "'TCP6:[${eltoroIp6}]:9119'")


    # nixbld1 stands in for a Nix build, which runs as a build user in group nixbld.
    restricted = ("hermes", "nixbld1")


    def assert_fence():
        for user in restricted:
            blocked(user, "TCP4", "${unlisted}:80")
            blocked(user, "TCP4", "${internetIp4}:80")
            allowed(user, "TCP4", "${allowedCidr}:80")
            allowed(user, "TCP4", "${allowedDns}:80")
            blocked(user, "TCP6", "[${internetIp6}]:80")
            blocked(user, "TCP4", "${peerIp4}:80")
            blocked(user, "TCP6", "[${peerIp6}]:80")
            allowed(user, "TCP4", "${magicDns}:53")
            allowed(user, "UDP4", "${magicDns}:53")
            blocked(user, "TCP4", "${magicDns}:5300")
            blocked(user, "UDP4", "${unlisted}:80")
            allowed(user, "UDP4", "${allowedCidr}:80")
            assert not pings(user, "${unlisted}"), f"{user} pinged ${unlisted}"
            assert pings(user, "${allowedCidr}"), f"{user} could not ping ${allowedCidr}"

        # Users other than the restricted ones are as unrestricted as root.
        for user in ("root", "nobody"):
            allowed(user, "UDP4", "${unlisted}:80")
            assert pings(user, "${unlisted}"), f"{user} could not ping ${unlisted}"
            allowed(user, "TCP4", "${unlisted}:80")
            allowed(user, "TCP6", "[${internetIp6}]:80")
            allowed(user, "TCP4", "${peerIp4}:80")
            allowed(user, "TCP6", "[${peerIp6}]:80")
            allowed(user, "TCP4", "${magicDns}:5300")

        for proto, target in (
            ("TCP4", "${routedIp4}:80"),
            ("TCP6", "[${routedIp6}]:80"),
            ("TCP4", "${lanIp4}:80"),
            ("TCP6", "[${lanIp6}]:80"),
        ):
            for user in restricted:
                blocked(user, proto, target)
            allowed("root", proto, target)

        assert_inbound_replies()
        for target in uplink_dashboard:
            internet.fail(f"echo hi | timeout 5 socat -t2 -T3 - {target}")


    def output_rules(save):
        return eltoro.execute(f"{save} -t filter | grep -E '^-A (OUTPUT|hermes-egress) '")[1].splitlines()


    def assert_rules_once():
        for save, count in (("iptables-save", 8), ("ip6tables-save", 5)):
            rules = output_rules(save)
            assert len(rules) == count, f"{save}: expected {count} rules, got {rules}"
            assert len(set(rules)) == count, f"{save}: duplicate rules in {rules}"


    def assert_closed():
        for user in restricted:
            blocked(user, "TCP4", "${allowedCidr}:80")
            blocked(user, "TCP4", "${unlisted}:80")
            blocked(user, "TCP6", "[${internetIp6}]:80")
            blocked(user, "TCP4", "${peerIp4}:80")
            blocked(user, "UDP4", "${magicDns}:53")
        allowed("root", "TCP4", "${unlisted}:80")
        allowed("root", "TCP6", "[${internetIp6}]:80")
        allowed("root", "TCP4", "${peerIp4}:80")
        assert_inbound_replies()
        # INPUT is open while the firewall is down, so the uplink can reach the
        # dashboard, and its replies pass the catch-all.
        for target in uplink_dashboard:
            assert "ok" in internet.succeed(f"echo hi | socat -t2 -T3 - {target}")
        for save in ("iptables-save", "ip6tables-save"):
            hooks = [rule for rule in output_rules(save) if rule.startswith("-A OUTPUT ")]
            assert hooks == ["-A OUTPUT -j hermes-egress-closed"], f"{save}: {hooks}"


    def unit_script(prop, probe=False):
        show = eltoro.succeed(f"systemctl show firewall -p {prop}")
        match = re.search(r"path=(\S+)", show)
        assert match, show
        path = "PATH=/etc/fence-probe:$PATH " if probe else ""
        eltoro.succeed(path + match.group(1))


    def peer_listener(unit, spec, netns="peer"):
        return f"systemd-run --unit={unit} -E PATH ip netns exec {netns} socat {spec},fork 'SYSTEM:echo ok'"


    start_all()
    internet.wait_for_unit("multi-user.target")
    eltoro.wait_for_unit("multi-user.target")
    eltoro.wait_for_unit("firewall.service")

    internet.succeed(
        "ip addr add ${unlisted}/32 dev lo",
        "ip addr add ${allowedCidr}/32 dev lo",
        "ip addr add ${allowedDns}/32 dev lo",
        # Bound to its address so the reply comes from where the probe sent it.
        "systemd-run --unit=udp-unlisted -E PATH socat UDP4-RECVFROM:80,bind=${unlisted},fork 'SYSTEM:echo ok'",
        "systemd-run --unit=udp-allowed -E PATH socat UDP4-RECVFROM:80,bind=${allowedCidr},fork 'SYSTEM:echo ok'",
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
        peer_listener("peer-80", "TCP6-LISTEN:80,reuseaddr"),
        peer_listener("peer-53", "TCP4-LISTEN:53,reuseaddr"),
        peer_listener("peer-53u", "UDP4-RECVFROM:53,bind=${magicDns}"),
        peer_listener("peer-5300", "TCP4-LISTEN:5300,reuseaddr"),
    )
    eltoro.wait_until_succeeds("test $(ip netns exec peer ss -Hlntu | wc -l) = 4")

    eltoro.succeed(
        "ip -n peer addr add ${routedIp4}/32 dev lo",
        "ip -n peer -6 addr add ${routedIp6}/128 dev lo",
        "ip route add ${routedIp4}/32 via ${peerIp4} dev tailscale0",
        "ip -6 route add ${routedIp6}/128 via ${peerIp6} dev tailscale0",
        "ip netns add lan",
        "ip link add lan0 type veth peer name far0",
        "ip link set far0 netns lan",
        "ip addr add 10.99.0.1/24 dev lan0",
        "ip -6 addr add fd00:99::1/64 dev lan0 nodad",
        "ip link set lan0 up",
        "ip -n lan addr add ${lanIp4}/24 dev far0",
        "ip -n lan -6 addr add ${lanIp6}/64 dev far0 nodad",
        "ip -n lan link set far0 up",
        peer_listener("lan-80", "TCP6-LISTEN:80,reuseaddr", netns="lan"),
    )
    eltoro.wait_until_succeeds("test $(ip netns exec lan ss -Hlnt | wc -l) = 1")
    eltoro.wait_for_open_port(9119)
    internet.wait_for_open_port(80)
    internet.wait_for_open_port(8080)
    internet.wait_until_succeeds("test $(ss -Hlnu sport = :80 | wc -l) = 2")

    eltoro.succeed("systemctl start egress-allowlist")

    with subtest("a nix build hermes requests is fenced like hermes"):
        status, build_log = eltoro.execute(
            "runuser -u hermes -- nix-build /etc/fod-escape.nix --no-out-link 2>&1",
            timeout=300,
        )
        assert status != 0 and "allowed:ok" in build_log, build_log
        assert "unlisted:ok" not in build_log, build_log

    with subtest("nix's built-in fetcher is fenced like a build"):
        status, build_log = eltoro.execute(
            "runuser -u hermes -- nix-build /etc/builtin-fetch.nix --argstr host ${unlisted} --no-out-link 2>&1",
            timeout=300,
        )
        assert status != 0 and "Could not connect" in build_log, build_log
        out = eltoro.succeed(
            "runuser -u hermes -- nix-build /etc/builtin-fetch.nix --argstr host ${allowedCidr} --no-out-link",
            timeout=300,
        ).strip()
        assert eltoro.succeed(f"cat {out}") == "ok\n"

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

    with subtest("a fenced unit starts only while the chain is hooked in both families"):
        eltoro.succeed("systemctl start fenced")
        eltoro.succeed("systemctl stop firewall")
        eltoro.fail("systemctl start fenced")
        eltoro.succeed("systemctl start firewall", "ip6tables -w -D OUTPUT -j hermes-egress")
        eltoro.fail("systemctl start fenced")
        eltoro.succeed("systemctl reload firewall", "systemctl start fenced")
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
            eltoro.fail("systemctl start fenced")
            assert_closed()
            for ipt in ("iptables", "ip6tables"):
                eltoro.succeed(f"{ipt} -w -F sabotage", f"{ipt} -w -X sabotage")
            eltoro.succeed("systemctl reload firewall")
            assert_rules_once()
            assert_fence()

    with subtest("no moment without a fence"):
        for prop in ("ExecStart", "ExecReload", "ExecStop", "ExecStart"):
            unit_script(prop, probe=True)
        runs = int(eltoro.succeed("wc -l </tmp/probe-runs"))
        print(f"fence probe ran {runs} times")
        assert runs > 0, "the probe never ran"
        eltoro.fail("cat /tmp/unfenced")
        assert_rules_once()
        assert_fence()
  '';
}
