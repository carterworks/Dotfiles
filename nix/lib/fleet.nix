{
  tailnetDomain = "dropbear-tortoise.ts.net";
  adminSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR4/6L4CG8EylhmV7laHQyn81YfQTk63tKWP4y9GB2O";

  # LAN addresses that hosts depend on. TrueNAS exports NFS only to
  # prostagma's (DHCP, see TODO.md).
  lan = {
    truenas = "192.168.5.252";
    prostagma = "192.168.4.29";
  };

  # IDs that TrueNAS's ACLs grant and prostagma's services run as; both sides
  # read them from here (infra/truenas through its wrapper).
  nasIds = {
    apps = 568;
    humans = 3000;
    media = 3004;
  };
}
