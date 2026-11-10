{
  inputs,
  nixpkgs,
}:

system:

let
  overlay = import ./overlay.nix { inherit inputs; };
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ overlay ];
  };
  inherit (pkgs) agent-browser herdr hunk;
in
nixpkgs.lib.getAttrs (builtins.attrNames (overlay pkgs pkgs)) pkgs
// {
  agent-browser-skill = pkgs.runCommand "agent-browser-skill-${agent-browser.version}.md" { } ''
    cp "$(${agent-browser}/bin/agent-browser skills path agent-browser)/SKILL.md" "$out"
  '';
  herdr-skill = pkgs.runCommand "herdr-skill-${herdr.version}.md" { } ''
    ${herdr}/bin/herdr --skill > "$out"
  '';
  hunk-skill = pkgs.runCommand "hunk-review-skill-${hunk.version}.md" { } ''
    cp "$(${hunk}/bin/hunk skill path)" "$out"
  '';
}
