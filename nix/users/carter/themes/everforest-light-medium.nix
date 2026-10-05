{
  source = "https://github.com/sainnhe/everforest/blob/master/autoload/everforest.vim";
  appearance = "light";
  colors = {
    background = "#efebd4";
    surface = "#f4f0d9";
    hover = "#e6e2cc";
    border = "#bdc3af";
    accent = "#8da101";
    text = "#5c6a72";
    muted = "#829181";
    selection = "#eaedc8";
  };
  ghostty = {
    # List installed themes: ghostty +list-themes
    # https://ghostty.org/docs/features/theme
    theme = "Everforest Light Med";
  };
  apps = {
    # In Helix, type :theme followed by a space and press Tab for available names.
    # Built-in files (use filenames without .toml):
    # https://github.com/helix-editor/helix/tree/master/runtime/themes
    helix = "everforest_light";
    # In OpenCode V2, run /themes to browse themes; mode is set separately.
    # https://opencode.ai/v2/docs/cli/theme
    opencode = "everforest";
    # "terminal" follows Ghostty's palette. Built-in alternatives: search theme.name at
    # https://herdr.dev/docs/config-reference/
    herdr = "terminal";
    # Built-in theme names and previews:
    # https://zellij.dev/documentation/theme-list.html
    zellij = "everforest-light";
    zed = {
      # This is an upstream port installed locally, rather than a built-in theme.
      # Read themes[].name in the JSON at source.url for its available variants.
      # https://github.com/albertsko/zed-everforest/tree/main/themes
      name = "Everforest Light Medium (regular)";
      source = {
        url = "https://raw.githubusercontent.com/albertsko/zed-everforest/ffdd7e7a68ea39eaf9d52af5dfd5f09edf74af72/themes/everforest-regular.json";
        hash = "sha256-gwOcPreZ8IPk+8Od4e/xRfUkgKVdJEH2a+wV3TZpkLk=";
      };
    };
    obsidian = {
      # Browse community themes: Settings > Appearance > Themes > Manage.
      # For a pinned port, use the name in its manifest.json:
      # https://github.com/stellaaash/everforest-obsidian
      name = "Everforest";
      # Upstream gates its only light palette on a class Obsidian does not add.
      cssReplacements = [
        {
          from = ".theme-light.efs-light {";
          to = ".theme-light {";
        }
      ];
      source = {
        owner = "stellaaash";
        repo = "everforest-obsidian";
        rev = "5dc681d817a939436a169e319dc9bed8fe1d8e85";
        hash = "sha256-TQ69WG2I2DAMnwd60zy4Fjio4BwkIkQ8XyYymg5vmnI=";
      };
    };
  };
}
