{
  inputs,
  nixpkgs,
}:

system:

let
  lib = nixpkgs.lib;
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  localPackage = path: pkgs.callPackage path { };
  agent-browser = inputs.numtide-llm-agents.packages.${system}.agent-browser;
  herdr = inputs.numtide-llm-agents.packages.${system}.herdr;
  hunk = inputs.numtide-llm-agents.packages.${system}.hunk;
in
{
  dotbot = pkgs.dotbot;
  inherit agent-browser herdr hunk;
  agent-browser-skill = pkgs.runCommand "agent-browser-skill-${agent-browser.version}.md" { } ''
    cp "$(${agent-browser}/bin/agent-browser skills path agent-browser)/SKILL.md" "$out"
  '';
  herdr-skill = pkgs.runCommand "herdr-skill-${herdr.version}.md" { } ''
    ${herdr}/bin/herdr --skill > "$out"
  '';
  hunk-skill = pkgs.runCommand "hunk-review-skill-${hunk.version}.md" { } ''
    cp "$(${hunk}/bin/hunk skill path)" "$out"
  '';
  fnox = localPackage ./fnox.nix;
  nub = localPackage ./nub.nix;
}
// lib.optionalAttrs (system == "aarch64-darwin" || system == "x86_64-linux") {
  hex = pkgs.callPackage ./hex.nix { hexSource = inputs.hex; };
  t3code-cli = localPackage ./t3code-cli.nix;
  t3code-nightly = localPackage ./t3code-nightly.nix;
}
// lib.optionalAttrs (system == "aarch64-darwin") {
  delta = localPackage ./delta.nix;
  vorssaint = localPackage ./vorssaint.nix;
}
// lib.optionalAttrs (lib.hasSuffix "-darwin" system) {
  rex-client = localPackage ./rex-client.nix;
}
// lib.optionalAttrs (system == "x86_64-linux") {
  delta = inputs.delta.packages.${system}.delta;
  bambu-studio = localPackage ./bambu-studio.nix;
  cua-driver = localPackage ./cua-driver.nix;
  ship-of-harkinian = localPackage ./ship-of-harkinian.nix;
}
