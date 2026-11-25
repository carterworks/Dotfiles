{ lib, config }:

let
  inherit (lib)
    any
    assertMsg
    concatMapStringsSep
    elem
    elemAt
    filter
    hasPrefix
    splitString
    ;

  container = config.virtualisation.oci-containers.containers.backrest;

  parse =
    volume:
    let
      parts = splitString ":" volume;
    in
    {
      inherit volume;
      source = elemAt parts 0;
      target = elemAt parts 1;
      options = splitString "," (if builtins.length parts > 2 then elemAt parts 2 else "");
    };

  volumes = map parse container.volumes;
  isUserdata = m: m.target == "/userdata" || hasPrefix "/userdata/" m.target;
  mounts = filter isUserdata volumes;
  required = config.systemd.services.docker-backrest.unitConfig.RequiresMountsFor;
  immich = config.services.immich.mediaLocation;

  # The ACLs on media and the homes let Backrest's groups write, so only the
  # bind's own `ro` stops a restore landing on the originals. Backrest writes
  # only to its own storage.
  writable = filter (
    m: !(hasPrefix "/srv/apps/backrest/" m.source) && !(elem "ro" m.options)
  ) volumes;
  unguarded = filter (m: !(elem m.source required)) mounts;
  # basic-plan runs restic with --one-file-system, which skips a mount inside
  # one of its paths.
  nested = filter (
    m: any (other: other.target != m.target && hasPrefix "${other.target}/" m.target) mounts
  ) mounts;
  # Only `volumes` is checked above.
  hidden = filter (
    o:
    any (p: hasPrefix p o) [
      "-v"
      "--volume"
      "--mount"
    ]
  ) container.extraOptions;

  list = ms: concatMapStringsSep ", " (m: m.volume) ms;
in
assert assertMsg (writable == [ ]) "Backrest mounts these read-write: ${list writable}";
assert assertMsg (
  unguarded == [ ]
) "docker-backrest does not require the mounts of: ${list unguarded}";
assert assertMsg (
  nested == [ ]
) "restic's --one-file-system skips these nested mounts: ${list nested}";
assert assertMsg (
  hidden == [ ]
) "Backrest's extraOptions add mounts this check cannot see: ${toString hidden}";
assert assertMsg (any (
  m: m.source == immich
) mounts) "Backrest does not mount Immich's library (${immich})";
true
