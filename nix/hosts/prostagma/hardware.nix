{ lib, ... }:

{
  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--101--disk--0";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
