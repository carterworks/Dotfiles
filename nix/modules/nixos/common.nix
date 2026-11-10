{ inputs, ... }:

{
  imports = [
    ../common.nix
    ./beszel-agent.nix
    ./binary-cache.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
  };

  time.timeZone = "America/Denver";

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };
}
