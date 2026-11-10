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
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (self.packages.${system}) agent-browser herdr hunk;
      # ./update copies `generated` into the tree; the check keeps them equal.
      skill =
        directory: generated:
        pkgs.runCommandLocal "${directory}-skill-check"
          {
            nativeBuildInputs = [ pkgs.diffutils ];
            passthru = { inherit generated; };
          }
          ''
            diff -u ${source}/agents/skills/generated/${directory}/SKILL.md ${generated}
            touch "$out"
          '';
    in
    {
      agent-browser-skill = skill "agent-browser" (
        pkgs.runCommand "agent-browser-skill-${agent-browser.version}.md" { } ''
          cp "$(${agent-browser}/bin/agent-browser skills path agent-browser)/SKILL.md" "$out"
        ''
      );
      herdr-skill = skill "herdr" (
        pkgs.runCommand "herdr-skill-${herdr.version}.md" { } ''
          ${herdr}/bin/herdr --skill > "$out"
        ''
      );
      hunk-skill = skill "hunk-review" (
        pkgs.runCommand "hunk-review-skill-${hunk.version}.md" { } ''
          cp "$(${hunk}/bin/hunk skill path)" "$out"
        ''
      );
      nixfmt = pkgs.runCommandLocal "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
        nixfmt --check ${lib.escapeShellArgs nixFiles}
        touch "$out"
      '';
      shellcheck = pkgs.runCommandLocal "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
        shellcheck --severity=warning ${source}/drift ${source}/install ${source}/update ${source}/tests/hermes-settings-writable
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
      drift =
        pkgs.runCommandLocal "drift-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.jq
              pkgs.python3
            ];
          }
          ''
            python3 ${source}/test-drift.py
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
      secrets-encrypted =
        pkgs.runCommandLocal "secrets-encrypted-check" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 -I ${./tests/secrets-encrypted.py} ${source}
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
        inherit (home.dotfiles.desktopTheme) theme;
        obsidian = home.xdg.configFile."desktop-theme/obsidian".source;
        manifest = pkgs.writeText "desktop-theme-check.json" (
          builtins.toJSON {
            inherit (theme) appearance apps colors;
            palettes = lib.mapAttrsToList (_: theme: theme.colors) home.dotfiles.desktopTheme.themes;
            files = {
              herdr = home.xdg.configFile."herdr/config.toml".source;
              vicinaeTheme = home.xdg.dataFile."vicinae/themes/${home.dotfiles.desktopTheme.name}.toml".source;
              helixBuiltin = "${pkgs.helix-unwrapped.src}/runtime/themes/${theme.apps.helix}.toml";
              zellijBuiltin = "${pkgs.zellij-unwrapped.src}/zellij-utils/assets/themes/${theme.apps.zellij}.kdl";
              zed = home.xdg.configFile."zed/themes/desktop-theme.json".source;
              obsidianSettings = home.xdg.configFile."desktop-theme/obsidian.json".source;
              audit =
                (lib.findFirst (package: package.name == "desktop-theme-audit") null home.home.packages).settings;
              obsidianManifest = "${obsidian}/manifest.json";
              obsidianCss = "${obsidian}/theme.css";
              kde = home.xdg.dataFile."color-schemes/${home.dotfiles.desktopTheme.name}.colors".source;
              gtk3 = home.xdg.configFile."gtk-3.0/colors.css".source;
              gtk4 = home.xdg.configFile."gtk-4.0/colors.css".source;
              gtk4Css = home.xdg.configFile."gtk-4.0/gtk.css".source;
              zellij = home.xdg.configFile."zellij/config.kdl".source;
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
      nub
      ;
    beszel =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux.extend (
          _: _: { inherit (self.packages.x86_64-linux) fnox; }
        );
      in
      pkgs.testers.runNixOSTest ./tests/beszel.nix;
    binary-cache = import ./tests/binary-cache.nix { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
    eltoro = eltoro.config.system.build.toplevel;
    eltoro-egress = nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest ./tests/eltoro-egress.nix;
    fnox-secrets =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux.extend (
          _: _: { inherit (self.packages.x86_64-linux) fnox; }
        );
      in
      pkgs.testers.runNixOSTest ./tests/fnox-secrets.nix;
    hermes-settings-repair = import ./tests/hermes-settings-repair.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      repair = eltoro.config.systemd.services.hermes-settings-repair.serviceConfig.ExecStart;
      activation = eltoro.config.system.activationScripts.hermes-settings.text;
    };
    prostagma = self.nixosConfigurations.prostagma.config.system.build.toplevel;
    scylla = scylla.config.system.build.toplevel;
  };
}
