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
    theme = "Everforest Light Med";
  };
  apps = {
    helix = "everforest_light";
    opencode = "everforest";
    herdr = "terminal";
    zellij = "everforest-light";
    zed = {
      name = "Everforest Light Medium (regular)";
      source = {
        url = "https://raw.githubusercontent.com/albertsko/zed-everforest/ffdd7e7a68ea39eaf9d52af5dfd5f09edf74af72/themes/everforest-regular.json";
        hash = "sha256-gwOcPreZ8IPk+8Od4e/xRfUkgKVdJEH2a+wV3TZpkLk=";
      };
    };
    obsidian = {
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
