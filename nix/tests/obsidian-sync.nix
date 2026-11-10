{ lib }:

let
  config =
    (lib.evalModules {
      specialArgs.pkgs.obsidian-headless = "/test/obsidian-headless";
      modules = [
        ../modules/home/obsidian-sync.nix
        {
          options = {
            home.homeDirectory = lib.mkOption {
              type = lib.types.str;
              default = "/home/carter";
            };
            home.profileDirectory = lib.mkOption {
              type = lib.types.str;
              default = "/home/carter/.nix-profile";
            };
            home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            systemd.user.services = lib.mkOption {
              type = lib.types.attrsOf lib.types.attrs;
              default = { };
            };
          };
        }
      ];
    }).config;
in
assert config.home.packages == [ "/test/obsidian-headless" ];
assert
  config.systemd.user.services.obsidian-sync.Service.ExecStart
  == "/test/obsidian-headless/bin/ob sync --path /home/carter/Documents/Notes --continuous";
assert config.systemd.user.services.obsidian-sync.Install.WantedBy == [ "default.target" ];
true
