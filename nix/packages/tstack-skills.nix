{
  lib,
  pkgs,
  inputs,
}:

(import ../lib/agent-skills.nix { inherit lib pkgs; }).skillSet {
  pname = "tstack-skills";
  version = "0-unstable-${lib.substring 0 8 inputs.tstack.lastModifiedDate}";
  src = "${inputs.tstack}/skills";
  skills = lib.genAttrs [
    "babysit-pr"
    "council"
    "file-pr"
    "full-send"
    "full-stop"
    "leaving-pr-comments"
    "modernize"
    "sol-loop"
    "takeover"
  ] lib.id;
  scripts = [ "babysit-pr/scripts/pr-wait" ];
  meta = {
    description = "Theo Browne's agent skills";
    homepage = "https://github.com/t3dotgg/tstack";
    license = lib.licenses.mit;
  };
}
