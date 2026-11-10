{ inputs }:

final: prev:

let
  inherit (prev.stdenv.hostPlatform) isDarwin isLinux system;
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
  hermes-agent = inputs.hermes-agent.packages.${system}.default;
  zen-browser = inputs.zen-browser.packages.${system}.beta;
  # nixpkgs' fnox fails to build, so it is never cached. See TODO.md.
  fnox = localPackage ./fnox.nix;
  hex = final.callPackage ./hex.nix { hexSource = inputs.hex; };
  nub = localPackage ./nub.nix;
  # Upstream publishes self-contained nightly builds, so these wrap them instead
  # of using llm-agents' source builds.
  t3code-cli = localPackage ./t3code-cli.nix;
  t3code-nightly = localPackage ./t3code-nightly.nix;
}
// prev.lib.optionalAttrs isDarwin {
  rex-client = localPackage ./rex-client.nix;
  vorssaint = localPackage ./vorssaint.nix;
}
// prev.lib.optionalAttrs isLinux {
  bambu-studio = localPackage ./bambu-studio.nix;
  cua-driver = localPackage ./cua-driver.nix;
  ship-of-harkinian = localPackage ./ship-of-harkinian.nix;
}
