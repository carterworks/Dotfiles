# Activating the desktop theme

The shared palette now generates a KDE color scheme, Breeze GTK 3/4 color definitions, fish/fzf colors, btop selection, Satty chrome, and importable Telegram/Heroic themes. Existing editor/browser integrations are unchanged in intent; they must be activated, not replaced with another port.

## Apply and verify

Run `./install` for the full machine activation. A Home Manager-only activation updates the application configurations but does not install the revised system-owned `hypr-screenshot` command (Slurp overlay colors).

Run `desktop-theme-audit` afterwards. It is read-only, detects broken imports/configuration drift, and compares the live KDE role groups and Obsidian selection with the generated settings. Build-time `desktop-theme` checks remain independent of the live home.

Restart Quickshell once for the new QApplication pragma; a QML hot reload cannot change application type. Reopen native Qt/GTK apps if they do not respond to the KDE palette notification. Open a new fish shell for global color overrides and refreshed fzf options. Restart/reload editors and Zen to load settings/theme files as needed. `zed` on this host's PATH may refer to another utility; use the Zed desktop launcher rather than assuming that command starts the editor.

## Supported UI imports

- **Telegram Desktop:** open `~/.config/desktop-theme/telegram/everforest-light-medium.tdesktop-theme` in Telegram, preview, and apply. The archive includes color roles and a solid desktop-colored chat wallpaper. Telegram supplies defaults for roles not overridden. It is an initial palette integration, not a promise every app-specific state is pixel-identical; inspect the preview before confirming. No account storage was edited.
- **Heroic:** Settings → Accessibility → custom themes folder: `~/.config/desktop-theme/heroic`. Select `everforest-light-medium`. Reselect after regeneration to refresh the CSS. The CSS uses Heroic's supported body class and theme variables; mutable account/game settings remain untouched.
- **Satty:** automatically loads `~/.config/satty/overrides.css`. Annotation ink colors are deliberately unchanged.
- **Dolphin Emulator:** use the system/default Qt style first. A separate QSS file has not been added without evidence that it is needed.

## File ownership and preservation

`kdeglobals` is no longer relinked by Dotbot. A Home Manager activation merges theme-owned roles into the mutable config, preserves other groups, removes the stale color-scheme hash, and keeps a first backup at `kdeglobals.before-desktop-theme`. If the old file is a Dotbot symlink, it is replaced atomically; its repository target is never edited. Malformed configuration causes an error rather than being overwritten.

Obsidian retains its existing merge/backup behavior. Legacy fish universal variables remain on disk but are shadowed by declared global values. Existing btop/GTK files were backed up during this session's Home Manager activation with the suffix `before-theme-implementation`. Later btop preferences can be added through `programs.btop.settings` rather than modifying its generated file.

No unsupported Steam/Spotify/Discord modifications were added. MangoHud retains its intentional dark gaming overlay. Brave/Chrome themes, fallback Plasma/greeter polish, exact bat/Codex/Hermes syntax/skin matching, and limited-support system accent propagation remain optional follow-up work rather than being silently configured.

## Verification in this session

- Generated palette/settings/import-archive checks and safe activation tests passed.
- Home Manager generation applied successfully; `desktop-theme-audit` passed against the live home.
- Dolphin screenshot inspected: `/tmp/opencode/theme-implemented-dolphin.png`; native backgrounds now match the shared light palette.
- Satty screenshot inspected: `/tmp/opencode/theme-implemented-satty.png`; toolbar/canvas chrome uses the generated light palette without CSS errors.
- Scylla's full system derivation built successfully; formatting, shell, Dotbot config and Sunshine checks passed too.
- Quickshell restarted and loaded without the prior application-mode error. The tray menu path is enabled; individual third-party menu contents were not exhaustively inspected.
- Small shell text/hover/selection color pairs are checked for at least 4.5:1 contrast. The requested black focused-window text remains black.
- No reboot or full NixOS generation switch was performed during the preview activation.
