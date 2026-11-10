{ lib, store }:

let
  config = builtins.fromTOML (builtins.readFile store);
  providers = config.providers or { };
  # fnox stores base64 of an age file ("age-encryption.org/v1"), optionally
  # behind the prefix `fnox reencrypt` writes.
  ageFile = "YWdlLWVuY3J5cHRpb24ub3JnL3Yx";
  isCiphertext =
    value: lib.hasPrefix ageFile value || lib.hasPrefix "fnox-age-batch-v1:${ageFile}" value;
  checkProvider =
    name: provider:
    lib.assertMsg (
      provider.type or null == "age"
      && provider.recipients != [ ]
      && lib.all (recipient: !lib.hasPrefix "AGE-SECRET-KEY-" recipient) provider.recipients
    ) "secrets/fnox.toml: provider ${name} must be age with public-key recipients only";
  checkSecret =
    name: secret:
    lib.assertMsg (
      lib.attrNames secret == [
        "provider"
        "value"
      ]
      && providers ? ${secret.provider}
      && isCiphertext secret.value
    ) "secrets/fnox.toml: ${name} is not age ciphertext from one of its providers";
in
lib.all lib.id (
  [
    (lib.assertMsg (
      config.default_provider or null == "admin"
    ) "secrets/fnox.toml: default_provider must stay admin")
  ]
  ++ lib.mapAttrsToList checkProvider providers
  ++ lib.mapAttrsToList checkSecret (config.secrets or { })
)
