{
  lib,
  pkgs,
  inputs,
}:

(import ../lib/agent-skills.nix { inherit lib pkgs; }).skillSet {
  pname = "mattpocock-skills";
  version = "1.3.2";
  src = "${inputs.mattpocock-skills}/skills";
  skills =
    lib.genAttrs [
      "codebase-design"
      "diagnosing-bugs"
      "domain-modeling"
      "grill-with-docs"
      "implement"
      "implement-spec"
      "improve-codebase-architecture"
      "pr"
      "retro"
      "tdd"
      "to-spec"
      "to-tickets"
      "triage"
      "wayfinder"
      "wizard"
    ] (name: "engineering/${name}")
    // lib.genAttrs [
      "grill-me"
      "grilling"
      "handoff"
      "teach"
      "to-questionnaire"
      "wait-what"
      "writing-for-agents"
    ] (name: "productivity/${name}")
    # Claude Code ships its own /code-review and /prototype, and Copilot CLI
    # its own /research; a bundled skill wins over a personal one.
    // {
      mp-code-review = "engineering/code-review";
      mp-prototype = "engineering/prototype";
      mp-research = "engineering/research";
    };
  passthru.updateInfo = {
    source = "github-release";
    owner = "mattpocock";
    repo = "skills";
    tagPrefix = "v";
    flakeInput = "mattpocock-skills";
    build = "source";
  };
  meta = {
    description = "Matt Pocock's agent skills";
    homepage = "https://github.com/mattpocock/skills";
    license = lib.licenses.mit;
  };
}
