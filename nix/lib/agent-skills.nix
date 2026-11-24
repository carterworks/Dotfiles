{ lib, pkgs }:

{
  # Copies the chosen skills of an upstream tree to share/agent-skills/<name>.
  # `skills` maps each installed name to the skill's directory in `src`. An
  # installed name that differs from the directory's own renames the skill:
  # its frontmatter `name`, and the references the other copied skills make to
  # it when they invoke it.
  skillSet =
    {
      pname,
      version,
      src,
      skills,
      # Scripts whose `#!/usr/bin/env` shebangs need a Nix interpreter.
      scripts ? [ ],
      passthru ? { },
      meta,
    }:
    let
      renames = lib.filterAttrs (name: path: baseNameOf path != name) skills;
      copy = lib.concatStrings (
        lib.mapAttrsToList (name: path: ''
          test -f ${src}/${path}/SKILL.md || {
            echo "${pname}: ${path} has no SKILL.md" >&2
            exit 1
          }
          cp -R ${src}/${path} "$dest/${name}"
        '') skills
      );
      rename = lib.concatStrings (
        lib.mapAttrsToList (
          name: path:
          let
            old = lib.escapeRegex (baseNameOf path);
          in
          ''
            sed -i -E 's/^name: ${old}$/name: ${name}/' "$dest/${name}/SKILL.md"
            find "$dest" -type f -name '*.md' -exec sed -i -E \
              -e 's/(Skill tool with )(["`])${old}(["`])/\1\2${name}\3/g' \
              -e 's/(^|[[:space:]`(])\/${old}([[:space:]`).,:;]|$)/\1\/${name}\2/g' \
              -e 's/`${old}` skill/`${name}` skill/g' \
              {} +
          ''
        ) renames
      );
    in
    pkgs.runCommand "${pname}-${version}"
      {
        inherit pname version meta;
        passthru = passthru // {
          skillNames = lib.attrNames skills;
        };
        buildInputs = lib.optional (scripts != [ ]) pkgs.python3;
      }
      ''
        dest=$out/share/agent-skills
        mkdir -p "$dest"
        ${copy}
        chmod -R u+w "$dest"
        # Codex-only interface metadata.
        find "$dest" -path '*/agents/openai.yaml' -delete
        find "$dest" -type d -name agents -empty -delete
        ${rename}
        ${lib.concatMapStrings (script: ''
          patchShebangs --host "$dest/${script}"
        '') scripts}

        for dir in "$dest"/*; do
          name="$(basename "$dir")"
          if ! sed -n '2,/^---$/p' "$dir/SKILL.md" | grep -qx "name: $name"; then
            echo "${pname}: $name/SKILL.md does not declare name: $name" >&2
            exit 1
          fi
        done
      '';
}
