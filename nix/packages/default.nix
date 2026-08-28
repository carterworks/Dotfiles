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
  hunk = inputs.hunk.packages.${system}.default;
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
  fff-mcp = localPackage ./fff-mcp.nix;
  nub = localPackage ./nub.nix;
  opencode2 = localPackage ./opencode2.nix;
  sdcpp-webui = localPackage ./sdcpp-webui.nix;
}
// lib.optionalAttrs (system == "x86_64-linux") {
  bambu-studio = localPackage ./bambu-studio.nix;
  obsidian-headless = localPackage ./obsidian-headless.nix;
}
