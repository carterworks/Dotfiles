{ self, nixpkgs }:

let
  inherit (nixpkgs) lib;
  source = self.outPath;
  nixFiles = lib.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive source);
  scylla = self.nixosConfigurations.scylla;
  eltoro = self.nixosConfigurations.eltoro;
  repositoryChecks =
    system:
    let
      browserSkill = self.packages.${system}.agent-browser-skill;
      herdrSkill = self.packages.${system}.herdr-skill;
      hunkSkill = self.packages.${system}.hunk-skill;
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      dotbot-config = pkgs.runCommandLocal "dotbot-config-check" { } ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        ${pkgs.dotbot}/bin/dotbot \
          --exit-on-failure \
          --dry-run \
          --base-directory ${source} \
          --config-file ${source}/install.conf.yaml
        touch "$out"
      '';
      agent-browser-skill =
        pkgs.runCommandLocal "agent-browser-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; }
          ''
            diff -u ${source}/agents/skills/generated/agent-browser/SKILL.md ${browserSkill}
            touch "$out"
          '';
      hunk-skill = pkgs.runCommandLocal "hunk-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
        diff -u ${source}/agents/skills/generated/hunk-review/SKILL.md ${hunkSkill}
        touch "$out"
      '';
      herdr-skill =
        pkgs.runCommandLocal "herdr-skill-check" { nativeBuildInputs = [ pkgs.diffutils ]; }
          ''
            diff -u ${source}/agents/skills/generated/herdr/SKILL.md ${herdrSkill}
            touch "$out"
          '';
      nixfmt = pkgs.runCommandLocal "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
        nixfmt --check ${lib.escapeShellArgs nixFiles}
        touch "$out"
      '';
      shellcheck = pkgs.runCommandLocal "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
        shellcheck --severity=warning ${source}/check ${source}/install ${source}/install-eltoro ${source}/update ${source}/tests/hermes-settings-writable
        touch "$out"
      '';
      install =
        pkgs.runCommandLocal "install-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.python3
            ];
          }
          ''
            python3 ${source}/test-install.py
            touch "$out"
          '';
      install-eltoro =
        pkgs.runCommandLocal "install-eltoro-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.python3
            ];
          }
          ''
            python3 ${source}/test-install-eltoro.py
            touch "$out"
          '';
      update =
        pkgs.runCommandLocal "update-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.jq
              pkgs.python3
            ];
          }
          ''
            python3 ${source}/test-update.py
            touch "$out"
          '';
      obsidian-sync-module =
        assert import ./tests/obsidian-sync.nix { inherit lib; };
        pkgs.runCommandLocal "obsidian-sync-module-check" { } ''
          touch "$out"
        '';
    };
in
{
  aarch64-darwin = repositoryChecks "aarch64-darwin" // {
    inherit (self.packages.aarch64-darwin)
      dotbot
      hex
      rex-client
      nub
      ;
    carters-macbook-pro = self.darwinConfigurations."Carters-MacBook-Pro".system;
  };
  x86_64-linux = repositoryChecks "x86_64-linux" // {
    desktop-theme =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        home = scylla.config.home-manager.users.carter;
        theme = import (./modules/home/desktop-theme/themes + "/${home.dotfiles.desktopTheme.name}.nix");
        obsidian = home.xdg.configFile."desktop-theme/obsidian".source;
        manifest = pkgs.writeText "desktop-theme-check.json" (
          builtins.toJSON {
            inherit (theme) appearance apps colors;
            palettes = map (file: (import (./modules/home/desktop-theme/themes + "/${file}")).colors) (
              builtins.filter (lib.hasSuffix ".nix") (
                builtins.attrNames (builtins.readDir ./modules/home/desktop-theme/themes)
              )
            );
            fzfOptions = home.home.sessionVariables.FZF_DEFAULT_OPTS;
            files = {
              opencode = home.xdg.configFile."opencode/cli.json".source;
              opencodeBase = ../opencode/cli.json;
              herdr = home.xdg.configFile."herdr/config.toml".source;
              herdrBase = ../herdr/config.toml;
              vicinae = home.xdg.configFile."vicinae/desktop-theme.json".source;
              vicinaeTheme = home.xdg.dataFile."vicinae/themes/${home.dotfiles.desktopTheme.name}.toml".source;
              helix = home.xdg.configFile."helix/config.toml".source;
              helixBuiltin = "${pkgs.helix-unwrapped.src}/runtime/themes/${theme.apps.helix}.toml";
              zellijBuiltin = "${pkgs.zellij-unwrapped.src}/zellij-utils/assets/themes/${theme.apps.zellij}.kdl";
              zed = home.xdg.configFile."zed/themes/desktop-theme.json".source;
              obsidianSettings = home.xdg.configFile."desktop-theme/obsidian.json".source;
              obsidianManifest = "${obsidian}/manifest.json";
              obsidianCss = "${obsidian}/theme.css";
              kde = home.xdg.dataFile."color-schemes/${home.dotfiles.desktopTheme.name}.colors".source;
              gtk3 = home.xdg.configFile."gtk-3.0/colors.css".source;
              gtk4 = home.xdg.configFile."gtk-4.0/colors.css".source;
              gtk4Css = home.xdg.configFile."gtk-4.0/gtk.css".source;
              btop = home.xdg.configFile."btop/btop.conf".source;
              btopTheme =
                if theme.apps ? btopTheme then
                  home.xdg.configFile."btop/themes/${theme.apps.btop}.theme".source
                else
                  null;
              fish = home.xdg.configFile."fish/config.fish".source;
              zedSettings = home.xdg.configFile."zed/settings.json".source;
              zellij = home.xdg.configFile."zellij/config.kdl".source;
              heroic = home.xdg.configFile."desktop-theme/heroic/${home.dotfiles.desktopTheme.name}.css".source;
              telegram =
                home.xdg.configFile."desktop-theme/telegram/${home.dotfiles.desktopTheme.name}.tdesktop-theme".source;
            };
          }
        );
      in
      pkgs.runCommandLocal "desktop-theme-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${source}/nix/modules/home/desktop-theme/test-obsidian-theme.py
        python3 ${source}/nix/modules/home/desktop-theme/test-kde-theme.py
        python3 ${source}/nix/modules/home/desktop-theme/test-live-desktop-theme.py
        python3 ${source}/nix/hosts/scylla/test-vicinae-onboarding.py
        python3 ${source}/nix/modules/home/desktop-theme/test-desktop-theme.py ${manifest}
        touch "$out"
      '';
    sunshine-display =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.runCommandLocal "sunshine-display-check"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.jq
            pkgs.python3
            pkgs.util-linux
          ];
        }
        ''
          python3 ${source}/nix/hosts/scylla/test-sunshine-display.py
          touch "$out"
        '';
    inherit (self.packages.x86_64-linux)
      bambu-studio
      dotbot
      nub
      ;
    binary-cache = import ./tests/binary-cache.nix { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
    eltoro = eltoro.config.system.build.toplevel;
    eltoro-egress = nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest ./tests/eltoro-egress.nix;
    hermes-settings-repair = import ./tests/hermes-settings-repair.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      repair = eltoro.config.systemd.services.hermes-settings-repair.serviceConfig.ExecStart;
      activation = eltoro.config.system.activationScripts.hermes-settings.text;
    };
    prostagma = self.nixosConfigurations.prostagma.config.system.build.toplevel;
    scylla = scylla.config.system.build.toplevel;
  };
}
