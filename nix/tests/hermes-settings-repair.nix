{ pkgs, repair }:

pkgs.testers.runNixOSTest {
  name = "hermes-settings-repair";

  nodes.machine = {
    users.groups.hermes = { };
    users.users.hermes = {
      isSystemUser = true;
      group = "hermes";
      home = "/var/lib/hermes";
      createHome = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")


    def owner(path):
        return machine.succeed(f"stat -c %U {path}").strip()


    def fresh_dir():
        machine.succeed(
            "rm -rf /var/lib/hermes/.hermes",
            "install -d -o hermes -g hermes /var/lib/hermes/.hermes",
        )


    with subtest("no .hermes yet is quietly fine"):
        machine.succeed("${repair}")

    with subtest("a symlinked .hermes is refused"):
        machine.succeed(
            "mkdir -p /srv/victim && touch /srv/victim/config.yaml",
            "ln -s /srv/victim /var/lib/hermes/.hermes",
            "chown -h hermes:hermes /var/lib/hermes/.hermes",
        )
        machine.fail("${repair}")
        assert owner("/srv/victim/config.yaml") == "root", "followed the symlink"

    with subtest("a root-owned .hermes is refused"):
        machine.succeed(
            "rm /var/lib/hermes/.hermes",
            "install -d /var/lib/hermes/.hermes",
            "touch /var/lib/hermes/.hermes/config.yaml",
        )
        machine.fail("${repair}")
        assert owner("/var/lib/hermes/.hermes/config.yaml") == "root", "repaired inside a root-owned dir"

    with subtest("root-owned settings in a hermes-owned .hermes are repaired"):
        fresh_dir()
        machine.succeed(
            "install -o root -g hermes -m 600 /dev/null /var/lib/hermes/.hermes/config.yaml",
            "install -o root -g hermes -m 600 /dev/null /var/lib/hermes/.hermes/SOUL.md",
            "${repair}",
        )
        assert owner("/var/lib/hermes/.hermes/config.yaml") == "hermes"
        assert owner("/var/lib/hermes/.hermes/SOUL.md") == "hermes"

    with subtest("a symlinked settings file is left alone"):
        fresh_dir()
        machine.succeed(
            "touch /srv/linked",
            "ln -s /srv/linked /var/lib/hermes/.hermes/config.yaml",
            "${repair}",
        )
        assert owner("/srv/linked") == "root", "followed a symlinked config.yaml"

    with subtest("a settings file hard-linked to a root-owned file is left alone"):
        # Root makes the link, which fs.protected_hardlinks would stop hermes
        # from doing; the repair must not rely on that sysctl.
        fresh_dir()
        machine.succeed(
            "touch /srv/hardlinked",
            "ln /srv/hardlinked /var/lib/hermes/.hermes/config.yaml",
            "${repair}",
        )
        assert owner("/srv/hardlinked") == "root", "chowned through a hard link"
  '';
}
