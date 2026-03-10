{
  pkgs,
  lib,
  ...
}:

{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  xdg.configFile."git/aliases".source = ../../git/aliases;

  programs.git = {
    enable = true;
    userName = "Carter McBride";
    userEmail = "18412686+carterworks@users.noreply.github.com";

    delta = {
      enable = true;
      options = {
        line-numbers = true;
      };
    };

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.local.*"
      "CLAUDE.md"
      "AGENTS.md"
      ".cursor/"
      ".worktrees/"
      ".osgrep/"
    ];

    includes = [
      { path = "aliases"; }
    ];

    extraConfig = {
      format.pretty = "%H %ci %ce %ae %d %s";
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      init.defaultBranch = "main";
      apply.whitespace = "fix";
      log.date = "iso";
      pull = {
        ff = "only";
        rebase = true;
      };
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      diff = {
        algorithm = "histogram";
        mnemonicPrefix = true;
        colorMoved = "plain";
        renames = true;
      };
      help.autocorrect = "prompt";
      commit.verbose = true;
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      merge.conflictstyle = "zdiff3";
      credential = {
        "https://github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "https://gist.github.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
        "https://git.corp.adobe.com" = {
          helper = [
            ""
            "!${lib.getExe pkgs.gh} auth git-credential"
          ];
        };
      };
    };
  };
}
