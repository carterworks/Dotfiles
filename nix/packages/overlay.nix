{ inputs }:

final: prev:

let
  lib = prev.lib;
  system = prev.stdenv.hostPlatform.system;
  localPackage = path: final.callPackage path { };
in
{
  inherit (inputs.numtide-llm-agents.packages.${system})
    agent-browser
    claude-code
    codex
    herdr
    hunk
    opencode2
    opencode2-desktop
    openspec
    ;
  # nixpkgs' fnox fails to build, so it is never cached. See TODO.md.
  fnox = localPackage ./fnox.nix;
  nub = localPackage ./nub.nix;
}
// lib.optionalAttrs (system == "aarch64-darwin" || system == "x86_64-linux") {
  hex = final.callPackage ./hex.nix { hexSource = inputs.hex; };
  t3code-cli = localPackage ./t3code-cli.nix;
  t3code-nightly = localPackage ./t3code-nightly.nix;
}
// lib.optionalAttrs (system == "aarch64-darwin") {
  vorssaint = localPackage ./vorssaint.nix;
}
// lib.optionalAttrs (lib.hasSuffix "-darwin" system) {
  rex-client = localPackage ./rex-client.nix;
}
// lib.optionalAttrs (system == "x86_64-linux") {
  bambu-studio = localPackage ./bambu-studio.nix;
  cua-driver = localPackage ./cua-driver.nix;
  ship-of-harkinian = localPackage ./ship-of-harkinian.nix;
}
