{ lib }:

let
  evaluate =
    system:
    lib.evalModules {
      specialArgs = {
        pkgs.stdenv.hostPlatform = {
          inherit system;
          isLinux = system == "x86_64-linux";
        };
        self.packages.${system} = lib.optionalAttrs (system == "x86_64-linux") {
          obsidian-headless = "/test/obsidian-headless";
        };
      };
      modules = [
        ../users/carter/obsidian-sync.nix
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
    };
  darwin = (evaluate "aarch64-darwin").config;
  linux = (evaluate "x86_64-linux").config;
in
assert darwin.home.packages == [ ];
assert darwin.systemd.user.services == { };
assert linux.home.packages == [ "/test/obsidian-headless" ];
assert
  linux.systemd.user.services.obsidian-sync.Service.ExecStart
  == "/test/obsidian-headless/bin/ob sync --path /home/carter/Documents/Notes --continuous";
assert linux.systemd.user.services.obsidian-sync.Install.WantedBy == [ "default.target" ];
true
