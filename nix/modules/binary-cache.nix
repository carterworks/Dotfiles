{ config, lib, ... }:

let
  publicKey = config.dotfiles.binaryCache.publicKey;
in
{
  options.dotfiles.binaryCache.publicKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "Public key from `attic cache info fleet`. The cache stays off while this is null; see docs/binary-cache.md.";
    default = null;
  };

  config = lib.mkIf (publicKey != null) {
    nix.settings = {
      substituters = [ "http://prostagma.dropbear-tortoise.ts.net:8199/fleet" ];
      trusted-public-keys = [ publicKey ];
      # Nix makes five attempts, so its 15-second default would stall every
      # command for over a minute while the tailnet or prostagma is down.
      connect-timeout = 5;
      fallback = true;
    };
  };
}
