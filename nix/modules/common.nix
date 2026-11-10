{ inputs, self, ... }:

{
  nixpkgs.overlays = [
    # nixpkgs' fnox fails to build, so it is never cached. See TODO.md.
    (final: prev: {
      fnox = final.callPackage ../packages/fnox.nix { };
    })
  ];

  environment.interactiveShellInit = ''
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "@wheel"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs self; };
  };
}
