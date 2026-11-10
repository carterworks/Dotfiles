{
  config,
  lib,
  pkgs,
  ...
}:

let
  uplink = config.eltoro.egress.uplink;

  # --- outbound egress allowlist (hermes user only; root unrestricted) ---
  # domains the agent may reach on the internet. a root-run oneshot
  # resolves them into the `egress-allowed` ipset (refreshed every 5
  # min, entries self-expire after 2h so dead cdn ips fall away), and
  # firewall rules only let hermes-uid packets into that set. cdn
  # caveat: shared cdn ips (cloudflare/fastly) mean hermes can also
  # reach other tenants on those ips — accepted residual.
  egressAllowedDomains = [
    # discord (gateway, rest api, cdn, media)
    "discord.com"
    "discord.gg"
    "discordapp.com"
    "discordapp.net"
    "discord.media"
    "gateway.discord.gg"
    "cdn.discordapp.com"
    # github (flake inputs, agent tooling)
    "github.com"
    "api.github.com"
    "codeload.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    # node package registry (application development)
    "registry.npmjs.org"
    # nix caches / channels
    "cache.nixos.org"
    "channels.nixos.org"
    "tarballs.nixos.org"
    # exa (agent web search)
    "exa.ai"
    "api.exa.ai"
    # deduce (daily puzzle the agent plays; every endpoint — including
    # the POSTs for register/play/guess — lives on the deduce.fun apex,
    # and it sits on vercel anycast, so pin the dns answer as usual)
    "deduce.fun"
    # hermes's llm gateway (config.yaml: provider opencode-go, base_url
    # https://opencode.ai/zen/go/v1) — without this the agent can't infer
    "opencode.ai"
    "api.opencode.ai"
    # openrouter (config.yaml: provider openrouter, model
    # deepseek/deepseek-v4.1-flash) — hermes resolves this provider's key
    # from OPENROUTER_API_KEY only, and 402s on an unfunded opencode-go
    # account are not a fallback trigger, so openrouter has to be the
    # primary while the go plan is out of credit
    "openrouter.ai"
  ];
  # static cidr backbone alongside the dns refresh: cdn round-robins
  # hand out different ips per query, so dns-pinned /32s alone flap
  # (observed: github serving 140.82.113.5 between refreshes). ranges:
  # github (api/git/raw/objects), discord on cloudflare's dedicated
  # 162.159.128.0/17, fastly for nix caches + objects.githubusercontent,
  # cloudflare blocks where exa and opencode.ai live. shared-cdn caveat
  # applies to the cloudflare blocks.
  egressAllowedCidrs = [
    "140.82.112.0/20"
    "143.55.64.0/20"
    "185.199.108.0/22"
    "192.30.252.0/22"
    "162.159.128.0/17"
    "151.101.0.0/16"
    "146.75.0.0/16"
    "199.232.0.0/16"
    "172.65.0.0/16"
    "172.66.32.0/19"
  ];

  # resolve the egress allowlist domains into an ipset (see
  # egressAllowedDomains in the let block for why)
  egressAllowlistRefresh = pkgs.writeShellScript "egress-allowlist-refresh" ''
    set -euo pipefail
    ${pkgs.ipset}/bin/ipset create egress-allowed hash:net family inet timeout 7200 -exist 2>/dev/null || true
    for d in ${lib.concatStringsSep " " egressAllowedDomains}; do
      # domain may be unresolvable — a miss must not abort the
      # refresh (pipefail would otherwise kill the whole script)
      ( ${pkgs.getent}/bin/getent ahostsv4 "$d" 2>/dev/null || true ) |
        ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/sort -u |
        while read -r ip; do
          ${pkgs.ipset}/bin/ipset add egress-allowed "$ip" -exist
        done
    done
    for c in ${lib.concatStringsSep " " egressAllowedCidrs}; do
      ${pkgs.ipset}/bin/ipset add egress-allowed "$c" -exist
    done
  '';

  chain = "hermes-egress";
  # Whenever the chain is down (stopped, failed or mid-reload) this rejects
  # every new connection the agent opens, so the fence fails closed. Hooked
  # first in OUTPUT, so whatever sits there cannot let the agent past it.
  closed = "${chain}-closed";
  # Appending the new catch-all before deleting the old one from the head
  # means a catch-all is in force at every moment, whichever generation
  # wrote the old one.
  closeFence = ''
    for ipt in iptables ip6tables; do
      $ipt -w -N ${closed} 2>/dev/null || true
      stale=$($ipt -w -S ${closed} | grep -c '^-A' || true)
      $ipt -w -A ${closed} ! -o lo -m conntrack ! --ctstate ESTABLISHED,RELATED -m owner --uid-owner hermes -j REJECT
      for _ in $(seq "$stale"); do $ipt -w -D ${closed} 1; done
      $ipt -w -C OUTPUT -j ${closed} 2>/dev/null || $ipt -w -I OUTPUT -j ${closed}
    done
  '';
  openFence = ''
    for ipt in iptables ip6tables; do
      while $ipt -w -D OUTPUT -j ${closed} 2>/dev/null; do :; done
      $ipt -w -F ${closed} 2>/dev/null || true
      $ipt -w -X ${closed} 2>/dev/null || true
    done
  '';
  # Start, reload and stop all go through this, so no generation can leave
  # rules behind that a later generation's delete commands fail to match.
  removeRules = ''
    for ipt in iptables ip6tables; do
      while $ipt -w -D OUTPUT -j ${chain} 2>/dev/null; do :; done
      $ipt -w -F ${chain} 2>/dev/null || true
      $ipt -w -X ${chain} 2>/dev/null || true
      # TODO: delete after eltoro first switches to this generation. Older
      # generations appended straight to OUTPUT, and a switch only reloads.
      $ipt -w -S OUTPUT | grep -E '^-A OUTPUT .*-o (${uplink}|tailscale0) ' | while read -r _ rule; do
        $ipt -w -D $rule || true
      done
    done
  '';
in
{
  options.eltoro.egress.uplink = lib.mkOption {
    type = lib.types.str;
    default = "eth0";
    description = "Interface carrying hermes' internet egress. NixOS test VMs need eth1.";
  };

  config = {
    networking.firewall = {
      # The fence is an allowlist: once a packet is known to be hermes',
      # anything not accepted below is rejected, on every interface and in
      # both families, so a new NIC, a subnet route or an exit node on
      # tailscale0 opens nothing. Root and every other uid are unrestricted.
      #
      # el toro may not initiate connections INTO the tailnet
      # (lateral movement: herodotus/proxmox api, truenas, other
      # agents). replies to inbound sessions (ssh, dashboard)
      # still work via conntrack, and MagicDNS (100.100.100.100)
      # stays reachable so *.ts.net names keep resolving.
      # tailscale itself is unaffected: its control plane and
      # DERP relays run over eth0, not tailscale0.
      #
      # internet egress: hermes may only reach ips in the
      # egress-allowed ipset (refreshed by egress-allowlist.timer).
      # the agent's ipv6 egress is rejected outright — allowlisted
      # hosts all resolve over v4.
      extraCommands = ''
        ${closeFence}
        ${removeRules}
        ${pkgs.ipset}/bin/ipset create egress-allowed hash:net family inet timeout 7200 -exist 2>/dev/null || true
        iptables  -w -N ${chain}
        ip6tables -w -N ${chain}
        for ipt in iptables ip6tables; do
          $ipt -w -A ${chain} -m owner ! --uid-owner hermes -j ACCEPT
          $ipt -w -A ${chain} -o lo -j ACCEPT
          $ipt -w -A ${chain} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        done
        iptables  -w -A ${chain} -o tailscale0 -d 100.100.100.100 -p udp -m udp --dport 53 -j ACCEPT
        iptables  -w -A ${chain} -o tailscale0 -d 100.100.100.100 -p tcp -m tcp --dport 53 -j ACCEPT
        iptables  -w -A ${chain} -o ${uplink} -m set --match-set egress-allowed dst -j ACCEPT
        iptables  -w -A ${chain} -j REJECT --reject-with icmp-admin-prohibited
        ip6tables -w -A ${chain} -j REJECT --reject-with icmp6-adm-prohibited
        # hook last so a half-filled chain is never live
        iptables  -w -A OUTPUT -j ${chain}
        ip6tables -w -A OUTPUT -j ${chain}
        ${openFence}
      '';
      extraStopCommands = ''
        ${closeFence}
        ${removeRules}
      '';
    };

    # resolve the egress allowlist domains into the ipset the
    # firewall rules reference; entries expire so stale cdn ips
    # fall away if a domain stops resolving
    systemd.services.egress-allowlist = {
      description = "Refresh hermes egress ip allowlist";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = egressAllowlistRefresh;
      };
    };
    systemd.timers.egress-allowlist = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5min";
      };
    };
  };
}
