{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.stylix.targets.cosmic;
  colors = config.lib.stylix.colors.withHashtag;
  polarity = if config.stylix.polarity == "either" then "light" else config.stylix.polarity;

  hexToBytes = hex:
    let h = lib.removePrefix "#" hex;
    in {
      red = lib.fromHexString (builtins.substring 0 2 h);
      green = lib.fromHexString (builtins.substring 2 2 h);
      blue = lib.fromHexString (builtins.substring 4 2 h);
    };

  byteToUnit = byte:
    if byte == 0 then
      "0.0"
    else if byte == 255 then
      "1.0"
    else
      let scaled = lib.div (byte * 1000000) 255;
      in "0.${lib.fixedWidthNumber 6 scaled}";

  mkRgb = rgb: ''
    (
        red: ${byteToUnit rgb.red},
        green: ${byteToUnit rgb.green},
        blue: ${byteToUnit rgb.blue},
    )
  '';

  mkRgba = rgb: ''
    (
        red: ${byteToUnit rgb.red},
        green: ${byteToUnit rgb.green},
        blue: ${byteToUnit rgb.blue},
        alpha: 1.0,
    )
  '';

  mkTuple4 = a: b: c: d: ''(${a}, ${b}, ${c}, ${d})'';

  mkOptionalRgb = hex: ''Some(${mkRgb (hexToBytes hex)})'';
  mkOptionalRgba = hex: ''Some(${mkRgba (hexToBytes hex)})'';

  neutralScale = if polarity == "dark" then [
    colors.base00
    colors.base01
    colors.base01
    colors.base02
    colors.base02
    colors.base03
    colors.base04
    colors.base05
    colors.base05
    colors.base06
    colors.base07
  ] else [
    colors.base00
    colors.base00
    colors.base01
    colors.base01
    colors.base02
    colors.base03
    colors.base04
    colors.base05
    colors.base05
    colors.base06
    colors.base07
  ];

  paletteVariant = if polarity == "dark" then "Dark" else "Light";
  paletteName = "stylix-${polarity}";

  paletteText =
    let
      paletteColor = hex: mkRgba (hexToBytes hex);
      neutral = index: paletteColor (builtins.elemAt neutralScale index);
    in
    ''
      ${paletteVariant}((
          name: "${paletteName}",
          blue: ${paletteColor colors.base0D},
          red: ${paletteColor colors.base08},
          green: ${paletteColor colors.base0B},
          yellow: ${paletteColor colors.base0A},
          gray_1: ${paletteColor colors.base01},
          gray_2: ${paletteColor colors.base02},
          neutral_0: ${neutral 0},
          neutral_1: ${neutral 1},
          neutral_2: ${neutral 2},
          neutral_3: ${neutral 3},
          neutral_4: ${neutral 4},
          neutral_5: ${neutral 5},
          neutral_6: ${neutral 6},
          neutral_7: ${neutral 7},
          neutral_8: ${neutral 8},
          neutral_9: ${neutral 9},
          neutral_10: ${neutral 10},
          bright_green: ${paletteColor colors.base0B},
          bright_red: ${paletteColor colors.base08},
          bright_orange: ${paletteColor colors.base09},
          ext_warm_grey: ${paletteColor colors.base03},
          ext_orange: ${paletteColor colors.base09},
          ext_yellow: ${paletteColor colors.base0A},
          ext_blue: ${paletteColor colors.base0D},
          ext_purple: ${paletteColor colors.base0E},
          ext_pink: ${paletteColor colors.base0F},
          ext_indigo: ${paletteColor colors.base0C},
          accent_blue: ${paletteColor colors.base0D},
          accent_red: ${paletteColor colors.base08},
          accent_green: ${paletteColor colors.base0B},
          accent_warm_grey: ${paletteColor colors.base03},
          accent_orange: ${paletteColor colors.base09},
          accent_yellow: ${paletteColor colors.base0A},
          accent_purple: ${paletteColor colors.base0E},
          accent_pink: ${paletteColor colors.base0F},
          accent_indigo: ${paletteColor colors.base0C},
      ))
    '';

  spacingText = ''
    (
        space_none: 0,
        space_xxxs: 4,
        space_xxs: 8,
        space_xs: 12,
        space_s: 16,
        space_m: 24,
        space_l: 32,
        space_xl: 48,
        space_xxl: 64,
        space_xxxl: 128,
    )
  '';

  cornerRadiiText = ''
    (
        radius_0: ${mkTuple4 "0.0" "0.0" "0.0" "0.0"},
        radius_xs: ${mkTuple4 "4.0" "4.0" "4.0" "4.0"},
        radius_s: ${mkTuple4 "8.0" "8.0" "8.0" "8.0"},
        radius_m: ${mkTuple4 "16.0" "16.0" "16.0" "16.0"},
        radius_l: ${mkTuple4 "32.0" "32.0" "32.0" "32.0"},
        radius_xl: ${mkTuple4 "160.0" "160.0" "160.0" "160.0"},
    )
  '';

  fontWeight = ''Normal'';
  fontStyle = ''Normal'';
  fontStretch = ''Normal'';
  mkFontText = name: ''
    Some((
        family: "${name}",
        stretch: ${fontStretch},
        style: ${fontStyle},
        weight: ${fontWeight},
    ))
  '';

  builderEntries = {
    "palette" = paletteText;
    "spacing" = spacingText;
    "corner_radii" = cornerRadiiText;
    "neutral_tint" = mkOptionalRgb colors.base03;
    "bg_color" = mkOptionalRgba colors.base00;
    "primary_container_bg" = mkOptionalRgba colors.base01;
    "secondary_container_bg" = mkOptionalRgba colors.base02;
    "text_tint" = mkOptionalRgb colors.base05;
    "accent" = mkOptionalRgb colors.base0D;
    "success" = mkOptionalRgb colors.base0B;
    "warning" = mkOptionalRgb colors.base0A;
    "destructive" = mkOptionalRgb colors.base08;
    "is_frosted" = "false";
    "gaps" = "(0, 8)";
    "active_hint" = "3";
    "window_hint" = mkOptionalRgb colors.base09;
  };

  themeName = if polarity == "dark" then "Dark" else "Light";
  builderFiles = builtins.listToAttrs (map
    (name: lib.nameValuePair "cosmic/com.system76.CosmicTheme.${themeName}.Builder/v1/${name}" {
      force = true;
      text = builderEntries.${name};
    })
    (builtins.attrNames builderEntries));
in
{
  options.stylix.targets.cosmic.enable = lib.mkEnableOption "COSMIC desktop theming";

  config = lib.mkIf (config.stylix.enable && cfg.enable && pkgs.stdenv.isLinux) {
    xdg.configFile = builderFiles // {
      "cosmic/com.system76.CosmicTheme.Mode/v1/is_dark" = {
        force = true;
        text = if polarity == "dark" then "true" else "false";
      };

      "cosmic/com.system76.CosmicTheme.Mode/v1/auto_switch" = {
        force = true;
        text = "false";
      };

      "cosmic/com.system76.CosmicTk/v1/apply_theme_global" = {
        force = true;
        text = "true";
      };

      "cosmic/com.system76.CosmicTk/v1/interface_font" = {
        force = true;
        text = mkFontText config.stylix.fonts.sansSerif.name;
      };

      "cosmic/com.system76.CosmicTk/v1/monospace_font" = {
        force = true;
        text = mkFontText config.stylix.fonts.monospace.name;
      };
    };

    home.activation.stylixCosmicTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.getExe pkgs.cosmic-ext-ctl} build-theme >/dev/null
    '';
  };
}
