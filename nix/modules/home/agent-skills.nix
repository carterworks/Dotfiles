{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  checkout = "${home}/.config/dotfiles";
  outOfStore = config.lib.file.mkOutOfStoreSymlink;

  animationsDev = {
    stateDir = "${config.xdg.stateHome}/agent-skills/animations-dev";
    # Claude Code has a hidden built-in /prototype; a built-in wins.
    renames.prototype = "ad-prototype";
    skills = [
      "ad-prototype"
      "animate"
      "animation-accessibility"
      "animation-performance"
      "animation-vocabulary"
      "css-animations"
      "debug-animation"
      "find-animation-opportunities"
      "gesture-ui"
      "improve-animations"
      "motion-brief"
      "motion-react"
      "pick-ui-library"
      "review-animations"
      "scroll-animations"
    ];
  };

  fromPackage =
    package: lib.genAttrs package.skillNames (name: "${package}/share/agent-skills/${name}");
  # Hand-written and tool-generated skills link into the checkout, so edits
  # apply without a switch.
  fromCheckout =
    dir:
    lib.mapAttrs (name: _: outOfStore "${checkout}/${dir}/${name}") (builtins.readDir ../../../${dir});

  sources = {
    personal = fromCheckout "agents/skills/personal";
    generated = fromCheckout "agents/skills/generated";
    tstack = fromPackage pkgs.tstack-skills;
    mattpocock = fromPackage pkgs.mattpocock-skills;
    modern-web-guidance.modern-web-guidance = "${pkgs.modern-web-guidance}/${pkgs.modern-web-guidance.skill}";
    # Paid content: animations-dev-sync fetches it into the state folder, never
    # into the repository or the store.
    animations-dev = lib.genAttrs animationsDev.skills (
      name: outOfStore "${animationsDev.stateDir}/current/${name}"
    );
  };

  skills = lib.foldl' (all: source: all // source) { } (lib.attrValues sources);
  # Links out of the store, which Home Manager's skill options try to read at
  # build time, where the checkout and state folder are out of reach.
  live = lib.filterAttrs (_: lib.isDerivation) skills;
  stored = lib.filterAttrs (_: source: !lib.isDerivation source) skills;

  owners = lib.zipAttrs (lib.mapAttrsToList (source: lib.mapAttrs (_: _: source)) sources);
  duplicates = lib.filterAttrs (_: from: lib.length from > 1) owners;

  animations-dev-sync = pkgs.writeShellApplication {
    name = "animations-dev-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fnox
    ];
    text = ''
      # The repository's store, not a personal global fnox config.
      export FNOX_CONFIG_DIR=/var/empty
      export FNOX_AGE_KEY_FILE="''${FNOX_AGE_KEY_FILE:-$HOME/.config/fnox/age.txt}"
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      fnox --no-daemon -c ${lib.escapeShellArg "${checkout}/secrets/fnox.toml"} get ANIMATIONS_DEV_TOKEN \
        | base64 -d \
        | ${lib.getExe pkgs.python3} -I ${../../../agents/animations-dev/sync.py} \
          --dest ${lib.escapeShellArg animationsDev.stateDir} \
          --expected ${lib.concatStringsSep "," animationsDev.skills} \
          ${
            lib.escapeShellArgs (
              lib.concatLists (lib.mapAttrsToList (old: new: [ "--rename=${old}=${new}" ]) animationsDev.renames)
            )
          } \
          "$@"
    '';
  };
in
{
  assertions = [
    {
      assertion = duplicates == { };
      message = "Agent skills with the same name from more than one source: ${
        lib.concatStringsSep "; " (
          lib.mapAttrsToList (name: from: "${name} (${lib.concatStringsSep ", " from})") duplicates
        )
      }";
    }
  ];

  # OpenCode also reads ~/.claude/skills, so this one directory serves both.
  # Claude Code comes from each host's own packages.
  programs.claude-code = {
    enable = true;
    package = null;
    configDir = "${home}/.claude";
    skills = stored;
  };

  # Copilot CLI stopped reading ~/.claude. Its own skills option links store
  # directories file by file, so these are one link per skill.
  home.file =
    lib.mapAttrs' (name: source: lib.nameValuePair ".claude/skills/${name}" { inherit source; }) live
    // lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".copilot/skills/${name}" {
        source = if lib.isDerivation source then source else outOfStore source;
      }
    ) skills;

  home.packages = [
    animations-dev-sync
    pkgs.modern-web-guidance
  ];

  # The skill-sync script this module replaced linked every skill into
  # ~/.claude/skills from ~/.agents/skills or ~/.config/opencode/skills; those
  # links would block Home Manager's. See TODO.md.
  home.activation.agentSkillsMigration = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for link in ${lib.escapeShellArg "${home}/.claude/skills"}/*; do
      [ -L "$link" ] || continue
      case "$(readlink "$link")" in
        ${lib.escapeShellArg "${home}/.agents/skills"}/* | ${lib.escapeShellArg "${home}/.config/opencode/skills"}/*)
          run rm -f "$link"
          ;;
      esac
    done
  '';

  home.activation.animationsDevSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -d ${lib.escapeShellArg "${animationsDev.stateDir}/current"} ]; then
      warnEcho "animations.dev skills are not fetched yet; run animations-dev-sync"
    fi
  '';
}
