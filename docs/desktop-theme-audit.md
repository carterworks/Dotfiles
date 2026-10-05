# Everforest desktop theme audit

Date: 2026-10-05. Baseline: `99c6fcf` on `feat/hyprland-sidebar-refinements`.

## Scope and evidence

Read-only audit of the Hyprland/Quickshell desktop, live configuration, Nix-generated configuration, and officially supported application theming. Steam, Spotify, injection-based skins, and arbitrary website restyling are excluded. Third-party theme *files* are in scope where the application officially supports loading them; this is different from patching an application's UI.

Evidence labels:

- **Observed:** live settings, filesystem checks, screenshots, or current process logs.
- **Declared:** repository/Nix configuration; not proof of activation.
- **Supported opportunity:** official interface exists, but appearance has not been verified visually.

Screenshots inspected (local temporary artifacts, not committed):

- `/tmp/opencode/theme-audit-dolphin.png`: white/gray KDE widgets and blue focus/selection beside the Everforest shell.
- `/tmp/opencode/theme-audit-notification.png`: themed notification surfaces, but faint secondary text.
- Earlier verified shell/Vicinae/Herdr screenshots: `/tmp/opencode/theme-after.png`, `/tmp/opencode/icon-tooltip-after.png`, `/tmp/opencode/vicinae-no-welcome.png`.

The audit opened and closed only its own Dolphin window and sent one temporary test notification. It did not switch the NixOS/Home Manager generation or modify app theme settings.

## Recommended order

1. **Apply existing integrations:** Zed, Helix, Zellij, Obsidian, Delta, OpenCode selection, and the broken Zen import. Verify the activated generation owns the files.
2. **Add one KDE palette adapter and Breeze GTK synchronization:** the biggest new coverage gain across native apps, dialogs and menus.
3. **Finish active CLI gaps:** fish's legacy RGB variables, btop's shipped Everforest theme, fzf's color scheme.
4. **Finish shell state/legibility styling and tray menus:** preserve the explicitly requested black focused labels.
5. **Add supported application adapters where used:** Telegram and Heroic; Satty; test Dolphin Emulator against the new system palette before adding QSS.
6. **Lower-priority supported surfaces:** Slurp selection overlay, MangoHud, Brave/Chrome themes, optional exact syntax/skin matching, fallback Plasma/greeter wallpaper.

No unsupported client modifications are required for any item above.

## First priority: apply definitions that already exist

`nix/users/carter/desktop-theme.nix` already declares several integrations that are **not reflected in the live home**. This is a deployment gap, not a reason to write another theme port.

| Surface | Declared target | Observed live state | Remaining work |
|---|---|---|---|
| Zed | Everforest Light Medium (regular), fixed light mode; local theme JSON | `~/.config/zed/settings.json` selects `Base16 selenized-light`; `~/.config/zed/themes/` has no local theme file | Activate generated settings and install the already-pinned JSON; then inspect panels, terminal, menus, and syntax |
| Helix | `everforest_light` | Live `config.toml` has no `theme` key | Activate generated config; don't infer the current in-memory theme from this alone |
| Zellij | `everforest-light` | Live config selects `solarized_light` | Activate generated config; inspect selected text/ribbons in the pinned port |
| Obsidian Notes vault | Everforest CSS, light `moonstone` mode, patched upstream light selector | `Documents/Notes/.obsidian/appearance.json` selects `Minimal`; only Minimal is installed in the vault's themes directory | Activate theme files and the existing appearance-update hook; preserve vault-specific font/preferences |
| OpenCode | Built-in `everforest`, fixed light mode | Live `cli.json` selects `system`, without a fixed mode | Apply the declaration if exact Everforest is desired. `system` is itself supported and follows Ghostty; it is not an unthemed default |
| Delta | `light = true` | Live Git config has an empty `[delta]` section and no effective Delta options | Activate the existing declaration; exact Everforest syntax/diff colors are a later optional pass |
| Zen | Generated shared CSS imported by the configured profile's `userChrome.css` | The import exists, but `~/.config/desktop-theme/zen.css` is a dangling symlink; its store target is absent | Restore the generated, generation-owned CSS; verify the active profile and browser chrome after reload/restart |

Official support: [Zed themes](https://zed.dev/docs/themes), [Zed visual customization](https://zed.dev/docs/visual-customization), [Helix themes](https://docs.helix-editor.com/themes.html), [Zellij themes](https://zellij.dev/documentation/themes.html), [Obsidian themes](https://obsidian.md/help/themes), [OpenCode V2 themes](https://opencode.ai/v2/docs/cli/theme), [Zen's documented userChrome workflow](https://github.com/zen-browser/docs/blob/main/content/docs/guides/live-editing.mdx).

The manually previewed Herdr/Vicinae store-file symlinks are currently valid, but should also become owned by the activated generation rather than remain ad hoc preview links. Do not assume a missing Zen store target was garbage-collected: that cause was not established.

## Biggest new integration: KDE/Qt and Breeze GTK

### KDE palette, not another widget-style dependency

**Observed in files and Dolphin screenshot.** The desktop already exports `QT_QPA_PLATFORMTHEME=kde` and selects KDE file-chooser/KWallet portal backends. Nevertheless, `~/.config/kdeglobals` is a Dotbot symlink to `kde/kdeglobals`, which contains Breeze role groups: white View background (`255,255,255`), gray Window background (`239,240,241`), and blue selection (`61,174,233`). No central Everforest adapter writes these roles.

Generate a complete KDE `.colors` scheme with Window, View, Button, Selection, Tooltip, Header, Complementary, link/status colors, and disabled/inactive effects. Apply its role groups, not just a `ColorScheme=Everforest` name: KDE's platform plugin reads the explicit color groups already present. Preserve non-theme groups and choose one file owner (Home Manager versus the current Dotbot link). Keep Breeze as the widget style unless there is a separate design reason to change it; qt5ct/qt6ct/Kvantum are not prerequisites.

This should cover compliant toolkit chrome in **Dolphin, System Settings and audio settings, Ark, Gwenview, Okular, Spectacle, KInfoCenter, Plasma System Monitor, KWallet, KDE polkit authentication, and KDE portal file dialogs**. Document/image content and application-forced palettes are separate. Native tray menus can follow it once their application-mode blocker is fixed.

Icons also have a declaration mismatch: GTK explicitly selects Papirus, while the main KDE settings lack an explicit icon theme and the KDE defaults choose Breeze. Verify the rendered set and decide whether to unify it. Application-supplied raster/brand icons are not guaranteed to obey a symbolic-icon theme.

Sources: [KDE theme architecture](https://develop.kde.org/docs/plasma/), [KDE Colors settings](https://docs.kde.org/trunk_kf6/en/plasma-workspace/kcontrol/colors/index.html), [KDE palette-loading source](https://github.com/KDE/plasma-integration/blob/master/qt6/src/platformtheme/khintssettings.cpp), [Qt application palette](https://doc.qt.io/qt-6/qapplication.html#setPalette), local `kde/kdeglobals`, `kde/kdedefaults/kdeglobals`, `install.conf.yaml`, and `nix/machines/scylla/hyprland.nix`.

### Breeze GTK color synchronization

**Observed file gaps.** GTK 3 imports its user `colors.css`, but that file still defines Breeze colors, including `#eff0f1` background and `#3daee9` selection. GTK 4's managed `gtk.css` imports the packaged Breeze stylesheet but not its user `colors.css`; the packaged definitions remain Breeze.

KDE officially supports synchronizing its palette into **Breeze GTK** with mapped color definitions for GTK 3 and GTK 4. Generate/update the color data and explicitly maintain the import ordering so it overrides packaged defaults. Having `kde-gtk-config` installed is not proof its KDED module runs in Hyprland; also avoid letting its mutable writer and Home Manager both own the same GTK CSS/settings files. Do not generalize this into unsupported blanket CSS overrides for every GTK/libadwaita application.

Sources: [KDE GTK integration README](https://github.com/KDE/kde-gtk-config/blob/master/README.md), [official color writer/imports](https://github.com/KDE/kde-gtk-config/blob/master/kded/config_editor/custom_css.cpp), [GTK settings/runtime](https://docs.gtk.org/gtk4/running.html), live `~/.config/gtk-3.0/colors.css` and `~/.config/gtk-4.0/gtk.css`.

### Supported system appearance/accent, not arbitrary libadwaita palettes

The live appearance portal returns `color-scheme=2` (**prefer light**), which is correct. Its `accent-color` key currently returns “Requested setting not found.” Completing supported accent propagation can benefit apps that follow that signal, but it does not give them full Everforest backgrounds.

Trayscale and the installed ProtonPlus use libadwaita. Count official system appearance/accent behavior only; no end-user arbitrary full-palette import was verified. Pinned ProtonPlus 0.5.19 offers System/Light/Dark, not the newer upstream Breeze theme selector. LM Studio and Handy likewise have supported appearance controls, but no verified arbitrary full-palette contract for this audit. These are **limited-support alignment checks**, not full-theme adapter tasks.

Sources: [appearance portal specification](https://github.com/flatpak/xdg-desktop-portal/blob/main/data/org.freedesktop.portal.Settings.xml), [libadwaita styles/appearance](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/styles-and-appearance.html), [pinned ProtonPlus selector](https://github.com/Vysp3r/ProtonPlus/blob/v0.5.19/src/widgets/preferences/theme-row.vala), [LM Studio themes](https://lmstudio.ai/docs/app/user-interface/themes), [Handy selector source](https://github.com/cjpais/Handy/blob/main/src/components/settings/ThemeSelector.tsx).

## Additional GUI applications with official custom-theme support

These are **supported opportunities**, not screenshot-confirmed bad app settings. Their mutable in-app theme selections were not inspected; the central module has no adapters for them.

| Application/surface | Official interface | Suggested scope |
|---|---|---|
| Telegram Desktop | `.tdesktop-theme` files, theme editor/import | Full supported palette; KDE's palette alone cannot recolor custom-rendered Telegram chrome. Use the app's official importer, not opaque account-storage edits |
| Heroic Games Launcher | Custom CSS themes and theme-folder selector | Generate one Everforest CSS theme and use the supported Accessibility/theme settings; this is explicitly supported CSS, not client injection |
| Dolphin Emulator | User `.qss`/`.css` styles plus Interface style selection | Test normal system Qt palette first; only add a custom style if needed. This is not KDE Dolphin |
| Satty | `~/.config/satty/overrides.css` | Theme screenshot-annotation chrome. Its annotation color palette is a separate, optional workflow choice. Installed through the screenshot command's closure, even though not directly on PATH |
| Slurp | Official `-b`, `-c`, `-s`, `-B` overlay colors | Screenshot script currently invokes bare `slurp`; map border/selection/backdrop colors deliberately |
| MangoHud | Background/text/metric/load-threshold color settings | Existing configuration forces translucent black and otherwise defaults. Theme supported colors if desired; a contrasting dark in-game overlay can be intentional |
| Brave / Chrome | Brave native GTK/Qt integration and browser appearance; Chrome theme extensions with official color roles | Lower priority if Zen is primary. Reuse native toolkit palette or supported theme packages; don't promise theme extensions recolor all internal pages/websites |
| Orca IDE terminal | Official custom terminal palettes/imports in current upstream | Reuse Ghostty palette only after checking installed-version import support. IDE chrome offers limited System/Light/Dark, not verified full-palette theming. This package is an agentic IDE, **not OrcaSlicer** |

Sources: [Telegram custom themes](https://core.telegram.org/themes), [Desktop theme reference](https://github.com/telegramdesktop/tdesktop/wiki/Theme-Reference), [Heroic custom themes](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Custom-Themes), [Dolphin Emulator styles](https://forums.dolphin-emu.org/Thread-user-style-thread), [Satty CSS](https://github.com/Satty-org/Satty#css), [pinned Satty CSS loader](https://github.com/gabm/Satty/blob/v0.20.1/src/main.rs), [Slurp manual](https://github.com/emersion/slurp/blob/master/slurp.1.scd), [MangoHud configuration](https://github.com/flightlessmango/MangoHud#hud-configuration), [Brave appearance](https://brave.com/whats-new/customize-appearance/), [Brave native Qt support/limitations](https://github.com/brave/brave-browser/issues/54969), [Chrome official theme format](https://developer.chrome.com/docs/extensions/develop/ui/themes), [Orca terminal theme UI](https://github.com/stablyai/orca/blob/main/src/renderer/src/components/settings/TerminalThemeSections.tsx).

## Login, lock and fallback Plasma: lower priority, limited to supported controls

This host uses **Plasma Login Manager, not SDDM**, with autologin. Supported wallpaper/clock/user/session settings can be aligned, but the greeter runs as a separate user; Carter's Home Manager theme does not automatically apply there. No documented SDDM-style arbitrary greeter theme-package interface was established, so do not propose one.

No Hyprlock/Swaylock/custom Quickshell lock screen was found. Plasma autolock and lock-on-resume are disabled in the existing config. Do not invent a missing Hyprlock theme task. If the fallback Plasma session is used, its panel/OSD/manual-lock styling is a separate official Plasma-theme surface and should be inspected after the KDE color scheme is complete.

Sources: [Plasma Login Manager supported settings](https://github.com/KDE/plasma-login-manager/blob/master/README.md), [pinned greeter module](https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/nixos/modules/services/display-managers/plasma-login-manager.nix), [KDE theme architecture](https://develop.kde.org/docs/plasma/), local `nix/machines/scylla.nix` and `kde/kscreenlockerrc`.

Steam, Spotify and client-modification approaches for Discord are not backlog items. Bambu Studio's built-in/native appearance controls are not a verified arbitrary-palette API; do not promise full Everforest custom green widgets or web views. OpenCode Desktop is distinct from the terminal client: V2's documented `cli.json` theme contract explicitly belongs to the terminal client, and no separate desktop full-palette contract was verified, so it is not included as a confirmed custom-theme task. [OpenCode V2 theme scope](https://opencode.ai/v2/docs/themes/).

## Terminal tools: confirmed gaps and optional matches

| Tool | Observed configuration | Remaining work through official support |
|---|---|---|
| fish | Mutable universal variables still contain Selenized RGB values: `909995` for secondary syntax and `d5cdb6` selection/search backgrounds | Declare `fish_color_*` and `fish_pager_color_*` using appropriate terminal colors or Everforest tokens. Do not replace the entire mutable `fish_variables` file |
| btop | `color_theme="Default"`, `theme_background=true`, truecolor; the installed default paints a black background | Select the already-installed `everforest-light-medium.theme` declaratively. No theme port/download is needed |
| fzf / fzf-fish | No color options; current fzf defaults to its dark scheme on this 256-color terminal | Declare `--color=base16` to follow terminal colors, or a light/custom scheme. Preserve the plugin's wanted layout defaults: setting `FZF_DEFAULT_OPTS` replaces its fallback options, not merely appends to them |
| bat, including fzf previews | No explicit theme; auto light/dark uses independent syntax palettes | Optional: `ansi` for terminal palette following, or a genuine imported Everforest `.tmTheme`. Pipe-based previews need deliberate detection/theme handling; don't invent a nonexistent bundled Everforest name |
| Codex CLI | No explicit TUI syntax theme; default uses light/dark Catppuccin syntax themes | Optional: installed schema supports `[tui] theme="ansi"` or a custom `.tmTheme`. This is a syntax-theme interface, not arbitrary whole-app CSS |
| Hermes CLI | No explicit `display.skin`; dashboard separately selects `mono` | Optional: official `/skin`, `display.skin`, and custom YAML skins can provide Everforest. The dashboard setting does not theme the CLI. Existing CLI skin already has a light overlay; don't label it necessarily dark |

Fish's old Base16 metadata is not itself an active source hook, but its RGB universal variables **are active**. In contrast, the old Starship `colors.toml` is not referenced. Starship defaults, Hunk, ordinary Git colors, Atuin defaults, and most Yazi light-preset UI colors already follow terminal colors and do not need a duplicate custom theme. Yazi preview syntax and eza's detailed file-class colors are optional exact-match work, not confirmed light/dark blockers. Lazygit and Claude CLI were not found on this Linux host; Copilot is declared only for Darwin, so they are not current scylla gaps.

Sources: [fish interactive colors](https://fishshell.com/docs/current/interactive.html#syntax-highlighting), [fish theme files](https://fishshell.com/docs/current/cmds/fish_config.html), [btop themes](https://github.com/aristocratos/btop#themes), [shipped btop Everforest](https://github.com/aristocratos/btop/blob/v1.4.7/themes/everforest-light-medium.theme), [fzf manual](https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1), [fzf-fish wrapper](https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_wrapper.fish), [bat themes](https://github.com/sharkdp/bat#highlighting-theme), [Delta color/style options](https://dandavison.github.io/delta/choosing-colors-styles.html), [installed Codex schema](https://github.com/openai/codex/blob/rust-v0.159.3/codex-rs/core/config.schema.json), [pinned Hermes skins](https://github.com/NousResearch/hermes-agent/blob/44a1ce9724502b9c692faaef00af3054bf11f1a6/website/docs/user-guide/features/skins.md), [Starship palette/styles](https://starship.rs/config/), [Atuin theming](https://docs.atuin.sh/latest/guide/theming/), [Yazi themes](https://yazi-rs.github.io/docs/configuration/theme), [eza color support](https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md).

## Quickshell: supported surfaces still needing polish

### Tray context menus: first restore the menu path, then theme it

**Observed + declared.** `quickshell/Sidebar.qml` calls `SystemTrayItem.display()` for context menus. `quickshell/shell.qml` does not contain `//@ pragma UseQApplication`. The running shell log reports:

> Cannot display PlatformMenuEntry as quickshell was not started in QApplication mode.

This is a functionality blocker, not just an off-palette popup. Two supported approaches exist:

1. Enable QApplication and let native menus follow the shared Qt/KDE palette.
2. Use `QsMenuOpener` and render the menu using the shell's own QML components/tokens.

Do not count tray artwork as a blanket gap: some tray/app icons are supplied as branded pixmaps rather than recolorable symbolic icons.

Sources: [Quickshell application pragma](https://quickshell.org/docs/v0.3.1/guide/advanced), [SystemTrayItem](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/SystemTrayItem), [QsMenuOpener](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsMenuOpener).

### Legibility and interaction-state tokens

**Measured from configured colors**, not estimated from screenshot antialiasing:

| Pair | Contrast |
|---|---:|
| Text `#5c6a72` / background `#efebd4` | 4.66:1 |
| Text / surface `#f4f0d9` | 4.87:1 |
| Text / hover `#e6e2cc` | 4.29:1 |
| Muted `#829181` / background | 2.77:1 |
| Muted / surface | 2.90:1 |
| Accent `#8da101` / background | 2.42:1 |

Using WCAG's 4.5:1 small-text threshold as a desktop legibility benchmark, notification bodies/app labels, the clock/date, workspace labels, media metadata, and some Vicinae/Herdr secondary text need a darker readable-muted token. Normal text on the hover fill narrowly misses that benchmark too. Keep green for suitable accents, not ordinary small labels. The black focused-window label was explicitly requested and should remain black.

`ShellButton.qml` also uses the same `Theme.hover` fill for selection and hover; the shared `selection` token is not exposed by `Theme.qml`. Custom button backgrounds do not distinguish pressed or keyboard-focus states. These are theme completeness opportunities, not requests to add animation.

Source: [W3C contrast guidance and formula](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html); local `quickshell/ShellButton.qml`, `Theme.qml`, `Sidebar.qml`, `NotificationCard.qml`, and `MediaCard.qml`.

### Typography and switchability

Several `Text` elements set a size but omit `font.family`: clock/date, notifications, media secondary metadata, and the empty-notifications message. Some other elements explicitly use Inter. Set a consistent inherited/default font before individually tweaking sizes.

The bundled SVGs deliberately hard-code black strokes. That works for this light theme and the requested black-label direction; recoloring them is **not** a necessary light-theme fix. It would become necessary for a truly switchable dark palette. Likewise, the static wallpaper is a deliberate image, with the theme background used only as a fallback; changing it is optional design work, not a missing application integration.

## Palette fidelity: don't mistake valid Everforest layers for mismatches

Everforest Light Medium defines several distinct backgrounds. The shared shell uses `#efebd4` (`bg_dim`/`bg2`), while the pinned Helix/Zed editor backgrounds use `#fdf6e3` (`bg0`). Both belong to the upstream medium palette. Do not flatten them just because screenshots differ.

Ghostty is already active with `Everforest Light Med`, `#efebd4` background, `#5c6a72` foreground, and `#eaedc8` selection. Its built-in normal ANSI colors differ from its bright colors and the exact semantic colors used by Herdr. If pixel-identical semantic reds/greens across CLI tools are desired, Ghostty officially allows palette overrides; otherwise this is a legitimate port choice, not an unthemed terminal. The old `~/.config/ghostty/theme` file contains Selenized but is **not referenced** by the active Ghostty config and is not evidence of an active theme defect.

Vicinae is active with the generated TOML. Its source derives many unspecified button/input/popover/tooltip colors from core colors, so an omitted override does **not** automatically indicate an unthemed surface. Inspect settings, action menus, grids, text selection, and hover states before extending the override table. Exact shared hover/pressed colors and contrast are the remaining fidelity checks, not another launcher theme rewrite.

Sources: [Everforest upstream palette](https://github.com/sainnhe/everforest/blob/master/autoload/everforest.vim), [pinned Zed port](https://github.com/albertsko/zed-everforest/blob/ffdd7e7a68ea39eaf9d52af5dfd5f09edf74af72/themes/everforest-regular.json), [Ghostty theme precedence/overrides](https://ghostty.org/docs/features/theme), [Vicinae derivation source](https://github.com/vicinaehq/vicinae/blob/v0.29.0/src/server/src/theme/theme-file.cpp).

## Validation gaps

The current `desktop-theme` check validates **generated artifacts**, not the active home or running applications. That is why it can pass while Zed, Helix, Zellij, and Obsidian retain previous themes. It also checks the Zed theme JSON rather than the effective live Zed selection, and has no live Zen import-existence check.

After activation, verify theme settings/file existence against the live home; reload/restart each app as required; and inspect default, selected, hovered, disabled, menu, tooltip, and notification states. Keep generated-artifact tests, but add a separately invoked deployment audit rather than letting build-time tests depend on a developer's home directory.

Hunk has no explicit local theme configuration or Home Manager settings here, but its installed v0.23.0 default is `terminal`, probing the host foreground/background and ANSI palette. It is already covered without additional theme configuration. Its `auto` mode instead chooses a light/dark GitHub theme. [Installed-version Hunk theme configuration](https://github.com/modem-dev/hunk/blob/v0.23.0/docs/themes.md).
