{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = lib.optional (inputs ? rex) inputs.rex.nixosModules.default;

  options.dotfiles.rex.enable = lib.mkEnableOption "the Rex shared Linux server";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !config.dotfiles.rex.enable || inputs ? rex;
          message = "Rex needs its gated flake input. Follow docs/rex.md before enabling dotfiles.rex.";
        }
      ];
    }
    (lib.optionalAttrs (inputs ? rex) {
      services.rex.enable = config.dotfiles.rex.enable;
      users.users.carter.extraGroups = lib.mkIf config.dotfiles.rex.enable [ "rex" ];
      users.users.rex.shell = lib.mkIf config.dotfiles.rex.enable pkgs.bashInteractive;
      nix.settings.netrc-file = lib.mkIf config.dotfiles.rex.enable (lib.mkDefault "/etc/nix/netrc");
    })
  ];
}
