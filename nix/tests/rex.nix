{ lib }:

let
  upstream = {
    options.services.rex.enable = lib.mkEnableOption "test Rex server";
  };
  evaluate =
    inputs: enable:
    lib.evalModules {
      specialArgs = {
        inherit inputs;
        pkgs.bashInteractive = "test-bash";
      };
      modules = [
        ../modules/rex.nix
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.attrs;
              default = [ ];
            };
            nix.settings.netrc-file = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            users.users = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    extraGroups = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                    };
                    shell = lib.mkOption {
                      type = lib.types.str;
                      default = "";
                    };
                  };
                }
              );
              default = { };
            };
          };
          config.dotfiles.rex.enable = enable;
        }
      ];
    };
  missing = evaluate { } false;
  invalid = evaluate { } true;
  available = {
    rex.nixosModules.default = upstream;
  };
  disabled = evaluate available false;
  enabled = evaluate available true;
in
assert builtins.all (entry: entry.assertion) missing.config.assertions;
assert !(builtins.all (entry: entry.assertion) invalid.config.assertions);
assert !(disabled.config.services.rex.enable);
assert disabled.config.users.users.carter.extraGroups == [ ];
assert disabled.config.users.users.rex.shell == "";
assert disabled.config.nix.settings.netrc-file == "";
assert enabled.config.services.rex.enable;
assert enabled.config.users.users.carter.extraGroups == [ "rex" ];
assert enabled.config.users.users.rex.shell == "test-bash";
assert enabled.config.nix.settings.netrc-file == "/etc/nix/netrc";
true
