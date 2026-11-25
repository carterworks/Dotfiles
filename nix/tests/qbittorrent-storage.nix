{ pkgs, prostagma }:

let
  qbittorrent = prostagma.systemd.services.docker-qbittorrent-vpn;
  guard = prostagma.systemd.services.prostagma-qbittorrent-space-guard;
  # tmpfs reports its size limit as free space without using memory, so the
  # guard sees as much headroom as the test asks for.
  tmpfs = size: {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=${size}" ];
  };
in
pkgs.testers.runNixOSTest {
  name = "qbittorrent-storage";

  nodes.machine = {
    virtualisation.fileSystems = {
      "/srv/apps" = tmpfs "64G";
      "/mnt/truenas/vm-data" = tmpfs "64G";
    };

    # The container is replaced by a process that only holds the unit up; the
    # test is about the unit's ties to its storage, not about Docker.
    systemd.services.docker-qbittorrent-vpn = {
      inherit (qbittorrent) bindsTo wantedBy;
      after = qbittorrent.bindsTo;
      unitConfig.RequiresMountsFor = qbittorrent.unitConfig.RequiresMountsFor;
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };

    systemd.services.prostagma-qbittorrent-space-guard = {
      inherit (guard) script serviceConfig;
    };
  };

  testScript = ''
    mount_unit = "mnt-truenas-vm\\x2ddata.mount"


    def settle():
        machine.wait_until_succeeds("test -z \"$(systemctl list-jobs --no-legend)\"")


    def run_guard():
        machine.succeed("systemctl start prostagma-qbittorrent-space-guard")
        settle()


    def qbittorrent_running():
        return machine.execute("systemctl is-active docker-qbittorrent-vpn")[0] == 0


    machine.wait_for_unit("multi-user.target")
    machine.succeed("install -d /mnt/truenas/vm-data/qbittorrent-downloads")
    machine.wait_for_unit("docker-qbittorrent-vpn.service")

    with subtest("healthy storage leaves qBittorrent running"):
        run_guard()
        assert qbittorrent_running(), "the guard stopped qBittorrent on healthy storage"

    with subtest("a storage probe that fails marks the guard failed but leaves qBittorrent running"):
        machine.succeed("rmdir /mnt/truenas/vm-data/qbittorrent-downloads")
        machine.fail("systemctl start prostagma-qbittorrent-space-guard")
        settle()
        assert qbittorrent_running(), "the guard stopped qBittorrent on a failed probe"
        machine.succeed("install -d /mnt/truenas/vm-data/qbittorrent-downloads")

    with subtest("losing the torrent mount stops qBittorrent"):
        machine.succeed("umount /mnt/truenas/vm-data")
        machine.wait_until_fails("systemctl is-active docker-qbittorrent-vpn", timeout=30)

    with subtest("the torrent mount coming back starts qBittorrent"):
        machine.succeed(f"systemctl start '{mount_unit}'")
        machine.wait_for_unit("docker-qbittorrent-vpn.service")
        machine.succeed("install -d /mnt/truenas/vm-data/qbittorrent-downloads")

    with subtest("critically low torrent storage stops qBittorrent"):
        machine.succeed("mount -o remount,size=1G /mnt/truenas/vm-data")
        run_guard()
        assert not qbittorrent_running(), "the guard left qBittorrent running with 1G free"
  '';
}
