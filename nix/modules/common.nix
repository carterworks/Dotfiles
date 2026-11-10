{ inputs, self, ... }:

let
  inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
in
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
    substituters = [ "https://cache.nixos.org" ] ++ extra-substituters;
    trusted-public-keys = extra-trusted-public-keys;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs self; };
  };
}
