{
  lib,
  theme,
  name,
}:
let
  inherit (theme) colors;
  rgb =
    color:
    lib.concatStringsSep "," (
      map (offset: toString (lib.fromHexString (builtins.substring offset 2 color))) [
        1
        3
        5
      ]
    );
  role = background: alternate: {
    BackgroundNormal = rgb background;
    BackgroundAlternate = rgb alternate;
    ForegroundNormal = rgb colors.text;
    ForegroundInactive = rgb colors.muted;
    ForegroundActive = rgb colors.text;
    ForegroundLink = rgb colors.link;
    ForegroundVisited = rgb colors.visited;
    ForegroundNegative = rgb colors.negative;
    ForegroundPositive = rgb colors.positive;
    ForegroundNeutral = rgb colors.warning;
    DecorationFocus = rgb colors.focus;
    DecorationHover = rgb colors.accent;
  };
  scheme = {
    General.Name = name;
    "Colors:Window" = role colors.background colors.surface;
    "Colors:View" = role colors.surface colors.background;
    "Colors:Button" = role colors.surface colors.background;
    "Colors:Selection" = role colors.selection colors.surface;
    "Colors:Tooltip" = role colors.surface colors.background;
    "Colors:Header" = role colors.background colors.surface;
    "Colors:Header][Inactive" = role colors.background colors.surface;
    "Colors:Complementary" = role colors.background colors.surface;
    "ColorEffects:Disabled" = {
      Color = rgb colors.border;
      ColorEffect = 0;
      ContrastEffect = 1;
      ContrastAmount = 0.55;
      IntensityEffect = 0;
    };
    "ColorEffects:Inactive" = {
      Enable = false;
      ChangeSelectionColor = false;
      Color = rgb colors.border;
      ColorEffect = 0;
      ContrastEffect = 0;
      IntensityEffect = 0;
    };
    WM = {
      activeBackground = rgb colors.background;
      activeBlend = rgb colors.background;
      activeForeground = rgb colors.text;
      inactiveBackground = rgb colors.background;
      inactiveBlend = rgb colors.background;
      inactiveForeground = rgb colors.muted;
    };
  };
  # Breeze's public named-color interface, also used by kde-gtk-config.
  gtkColors = {
    theme_bg_color = colors.background;
    theme_fg_color = colors.text;
    theme_base_color = colors.surface;
    theme_text_color = colors.text;
    content_view_bg = colors.surface;
    theme_selected_bg_color = colors.selection;
    theme_selected_fg_color = colors.text;
    theme_hovering_selected_bg_color = colors.selection;
    borders = colors.border;
    unfocused_borders = colors.border;
    unfocused_insensitive_borders = colors.border;
    link_color = colors.link;
    link_visited_color = colors.visited;
    tooltip_background = colors.surface;
    tooltip_text = colors.text;
    tooltip_border = colors.border;
    theme_view_active_decoration_color = colors.focus;
    theme_view_hover_decoration_color = colors.accent;
  }
  // lib.genAttrs [ "theme_unfocused_base_color" "theme_unfocused_view_bg_color" ] (_: colors.surface)
  // lib.genAttrs [ "theme_unfocused_bg_color" ] (_: colors.background)
  // lib.genAttrs [
    "theme_unfocused_fg_color"
    "theme_unfocused_text_color"
    "theme_unfocused_view_text_color"
    "theme_unfocused_selected_fg_color"
  ] (_: colors.text)
  // lib.genAttrs [ "theme_unfocused_selected_bg_color" "theme_unfocused_selected_bg_color_alt" ] (
    _: colors.selection
  )
  // lib.genAttrs [
    "insensitive_base_color"
    "insensitive_bg_color"
    "insensitive_selected_bg_color"
    "insensitive_unfocused_bg_color"
    "insensitive_unfocused_selected_bg_color"
  ] (_: colors.background)
  // lib.genAttrs [
    "insensitive_base_fg_color"
    "insensitive_fg_color"
    "insensitive_selected_fg_color"
    "insensitive_unfocused_fg_color"
    "insensitive_unfocused_selected_fg_color"
  ] (_: colors.muted)
  // {
    insensitive_borders = colors.border;
  }
  //
    lib.concatMapAttrs
      (state: suffix: {
        "theme_button_background${suffix}" = colors.surface;
        "theme_button_foreground${suffix}" = colors.text;
        "theme_button_foreground_active${suffix}" = colors.text;
        "theme_button_decoration_focus${suffix}" = colors.focus;
        "theme_button_decoration_hover${suffix}" = colors.accent;
      })
      {
        normal = "_normal";
        backdrop = "_backdrop";
        insensitive = "_insensitive";
        backdropInsensitive = "_backdrop_insensitive";
      }
  // {
    theme_button_foreground_active = colors.text;
    theme_button_decoration_focus = colors.focus;
    theme_button_decoration_hover = colors.accent;
  }
  //
    lib.concatMapAttrs
      (
        _: prefix:
        lib.genAttrs [
          "${prefix}_background"
          "${prefix}_background_light"
          "${prefix}_background_backdrop"
        ] (_: colors.background)
        // lib.genAttrs [
          "${prefix}_foreground"
          "${prefix}_foreground_backdrop"
          "${prefix}_foreground_insensitive"
          "${prefix}_foreground_insensitive_backdrop"
        ] (_: colors.text)
      )
      {
        header = "theme_header";
        titlebar = "theme_titlebar";
      }
  //
    lib.concatMapAttrs
      (
        kind: color:
        lib.genAttrs [
          "${kind}_color"
          "${kind}_color_backdrop"
          "${kind}_color_insensitive"
          "${kind}_color_insensitive_backdrop"
        ] (_: color)
      )
      {
        error = colors.negative;
        success = colors.positive;
        warning = colors.warning;
      };
in
{
  inherit scheme;
  # KConfig nested groups use literal ][ separators, not INI escaping.
  kde = lib.generators.toINI { mkSectionName = section: section; } scheme;
  gtk =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: color: "@define-color ${key}_breeze ${color};") gtkColors
    )
    + "\n";
}
