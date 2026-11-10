let
  flake = builtins.getFlake (toString ../.);
  system = builtins.currentSystem;
  inherit (flake.inputs.nixpkgs) lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  # Matching on names keeps a broken host from failing this job too, which
  # evaluating each check to identify it would.
  hosts = map lib.toLower (
    builtins.attrNames flake.nixosConfigurations ++ builtins.attrNames flake.darwinConfigurations
  );
  # rex-client is a requireFile of a gated download that CI cannot fetch.
  buildable = name: _: name != "rex-client" && !builtins.elem name hosts;
  mac = flake.darwinConfigurations."Carters-MacBook-Pro-2";
  withoutRex = flake // {
    packages = flake.packages // {
      ${system} = flake.packages.${system} // {
        rex-client = pkgs.emptyDirectory;
      };
    };
  };
  nixConfig = (import ../flake.nix).nixConfig;
in
{
  # getFlake ignores the flake's own nixConfig, so CI writes it to nix.conf.
  nixConf = ''
    extra-substituters = ${toString nixConfig.extra-substituters}
    extra-trusted-public-keys = ${toString nixConfig.extra-trusted-public-keys}
  '';
  checks = pkgs.linkFarm "checks" (lib.filterAttrs buildable flake.checks.${system});
  mac = (mac.extendModules { specialArgs.self = withoutRex; }).config.system.build.toplevel;
}
