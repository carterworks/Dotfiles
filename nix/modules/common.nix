{ inputs, self, ... }:

let
  inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      inherit (self.packages.${final.stdenv.hostPlatform.system})
        bambu-studio
        cua-driver
        # nixpkgs' fnox fails to build, so it is never cached. See TODO.md.
        fnox
        hex
        nub
        rex-client
        ship-of-harkinian
        t3code-cli
        t3code-nightly
        vorssaint
        ;
      inherit (inputs.numtide-llm-agents.packages.${final.stdenv.hostPlatform.system})
        agent-browser
        claude-code
        codex
        herdr
        hunk
        opencode2
        opencode2-desktop
        openspec
        ;
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
    extraSpecialArgs = { inherit inputs; };
  };
}
