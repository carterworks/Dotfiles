let
  colors = {
    background = "#e5e9f0";
    surface = "#eceff4";
    hover = "#d8dee9";
    pressed = "#cbd3df";
    border = "#a5abb6";
    accent = "#7bb3c3";
    text = "#414858";
    muted = "#4c566a";
    hoverText = "#3b4252";
    focus = "#5e81ac";
    selection = "#d8dee9";
    selectedText = "#4c556a";
    # Darker semantic UI accents; terminal ANSI colors stay faithful to Ghostty.
    link = "#40658b";
    visited = "#805a79";
    negative = "#a3444e";
    positive = "#526c3d";
    warning = "#806125";
  };
  component = background: {
    base = colors.text;
    inherit background;
    emphasis_0 = colors.warning;
    emphasis_1 = colors.link;
    emphasis_2 = colors.positive;
    emphasis_3 = colors.visited;
  };
in
{
  source = "https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/ghostty/Nord%20Light";
  appearance = "light";
  inherit colors;
  ghostty.theme = "Nord Light";
  apps = {
    helix = "nord_light";
    opencode = "nord";
    herdr = "terminal";
    btop = "nord-light";
    btopTheme = {
      main_bg = colors.background;
      main_fg = colors.text;
      title = colors.text;
      hi_fg = colors.link;
      selected_bg = colors.selection;
      selected_fg = colors.selectedText;
      inactive_fg = colors.muted;
      graph_text = colors.muted;
      meter_bg = colors.border;
      proc_misc = colors.visited;
      cpu_box = colors.link;
      mem_box = colors.positive;
      net_box = colors.visited;
      proc_box = colors.warning;
      div_line = colors.border;
    }
    // builtins.listToAttrs (
      builtins.concatMap
        (name: [
          {
            name = "${name}_start";
            value = colors.link;
          }
          {
            name = "${name}_mid";
            value = colors.positive;
          }
          {
            name = "${name}_end";
            value = colors.negative;
          }
        ])
        [
          "temp"
          "cpu"
          "free"
          "cached"
          "available"
          "used"
          "download"
          "upload"
          "process"
        ]
    );
    herdrColors = {
      mauve = "#b48ead";
      green = "#96b17f";
      yellow = "#c5a565";
      red = "#bf616a";
      blue = "#81a1c1";
      teal = "#7bb3c3";
      peach = "#d08770";
    };
    # Zellij ships only dark Nord; supply light UI components locally.
    zellij = "nord-light";
    zellijTheme = {
      text_unselected = component colors.background;
      text_selected = component colors.selection;
      ribbon_unselected = component colors.surface;
      ribbon_selected = component colors.selection;
      table_title = component colors.background;
      table_cell_unselected = component colors.background;
      table_cell_selected = component colors.selection;
      list_unselected = component colors.background;
      list_selected = component colors.selection;
      frame_unselected = (component colors.background) // {
        base = colors.border;
      };
      frame_selected = (component colors.background) // {
        base = colors.focus;
      };
      frame_highlight = (component colors.background) // {
        base = colors.link;
      };
      exit_code_success = (component colors.background) // {
        base = colors.positive;
      };
      exit_code_error = (component colors.background) // {
        base = colors.negative;
      };
    };
    zed = {
      name = "Nord Light";
      source = {
        url = "https://raw.githubusercontent.com/mikasius/zed-nord-theme/d0b459c49797aec598622bed992537e4a83688da/themes/nord.json";
        hash = "sha256-CONvCRq35bQe0IQQyMWo9zKleYjqOAJcuovSqQbpuhE=";
      };
    };
    obsidian = {
      name = "Obsidian Nord";
      source = {
        owner = "insanum";
        repo = "obsidian_nord";
        rev = "f40209f976fab19ae7590018591fd5311e6af7f4";
        hash = "sha256-LdjxEpxnsV4YXI9K72o2m6E1nhZvKb/r/WCuVKihugI=";
      };
    };
  };
}
