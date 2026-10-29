# Hyprland + Miasma sidebar

Hyprland uses its built-in **scrolling** layout: windows occupy columns on a
horizontal strip. Quickshell provides a 250 px sidebar, window/workspace lists,
launchers, audio, media controls, system tray, notifications, and the
`assets/wallpapers/01-miasma.jpg` background.

Lucide icons, compact pinned app buttons, flat window rows, and bottom-centered
workspace dots follow the Arc sidebar layout. A filled dot marks the active
space; click any outlined dot to switch to it. Click a window row to focus it,
or middle-click it to close it. The speaker button opens a native PipeWire
popover: choose the default output or input, then set per-device and
per-application volume and mute. Scroll the sidebar speaker to change the
default output volume; middle-click it to mute, and hover it to see the current
level. Port and profile selection are not part of the panel because
Quickshell's PipeWire service does not expose them; use `wpctl` for those.
Tray icons retain the icons supplied by their applications.
Trayscale starts hidden and supplies Tailscale's icon in the system tray.

## Activate

From the repository root, run `./install`. This links the configuration and
activates the NixOS generation. Save your work, log out, and choose
**Hyprland (uwsm-managed)** at the login screen. Choose the UWSM session, not the
plain Hyprland session: UWSM manages the sidebar and supporting services.

Plasma remains installed as a fallback. Passwordless autologin starts the
UWSM-managed Hyprland session. No locker or idle-locking service is added.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Super+Shift+Return | Ghostty |
| Super+Shift+F | Dolphin |
| Super+Shift+M | Spotify |
| Super+Shift+B | Zen |
| Ctrl+Space | Vicinae |
| Super+F | Toggle floating |
| Super+W | Close window |
| Super+Shift+Left / Right | Previous / next existing workspace |
| Super+1…0 | Workspace 1…10 |
| Super+Shift+1…0 | Move window to workspace 1…10 |
| Super+left-button drag | Move / reorder window |
| Super+right-button drag | Resize window |
| Super+scroll up / down | Focus previous / next window in current workspace |
| Super+Ctrl+Left / Right | Focus previous / next column |
| Super+Ctrl+Shift+Left / Right | Swap columns |
| Super+[ / ] | Cycle column width |
| Super+C | Center column |
| Super+, / . | Stack into previous column / split into own column |
| Super+Ctrl+F | Fullscreen |
| Super+Shift+R | Reload Hyprland configuration |
| Super+Ctrl+R | Restart Quickshell |
| Super+Shift+Escape | Log out immediately |
| Print | Select screenshot region and annotate with Satty |

## Theme

Set `dotfiles.desktopTheme.name` in `nix/users/carter/home-manager.nix` to
select a theme. The initial theme is `everforest-light-medium`. Add other theme
files under `nix/users/carter/themes/`; each file has named UI colours,
native Ghostty settings, and an `apps` attribute with application theme names
and pinned upstream downloads. No Base16 or wallpaper colour generator is used.

Run `./install` to apply the selection. Reload Hyprland and Ghostty, restart
Quickshell, and restart Zen. Reopen editors and terminal applications to load
their new settings. Close Obsidian before applying so it cannot write stale
appearance settings back. Switching is declarative, not a live toggle.

Home Manager creates `quickshell/DesktopColors.qml`,
`hypr/desktop-colors.lua`, and `desktop-theme/zen.css`. The shell and compositor
read these files. Ghostty uses its existing Everforest Light Medium theme.
The shell and browser use its `#efebd4` background (Everforest's `bg_dim`).

`dotfiles.desktopTheme.zenProfile` points to the existing Zen profile. No new
profile is created, and `profiles.ini` is not changed. Set this path for a new
machine, or set it to `null` to leave the browser unmanaged. Home Manager manages
`chrome/userChrome.css` and `user.js` in this profile. It will stop if either file
already exists with different content; do not remove existing custom settings.
The CSS changes the browser UI, not website colours. GTK stays on light Breeze.

### Application themes

The same selection configures:

| Application | Theme source |
| --- | --- |
| Helix | Built-in `everforest_light` (Light Medium) |
| OpenCode V2 | Built-in `everforest`, explicitly in light mode |
| Herdr | Terminal palette inherited from Ghostty; automatic switching disabled |
| Zed | Pinned upstream Everforest Light Medium (regular) theme |
| Obsidian | Pinned upstream Everforest theme, in light mode |
| Zellij | Built-in `everforest-light` |
| Delta | Light-mode diffs using the terminal palette |

These are existing application ports, not pixel-identical generated themes.
Zed's theme is installed locally, so theme extension updates cannot change the
pinned palette. Edit `opencode/cli.json` and `herdr/config.toml` for non-theme
settings; Home Manager merges in the selected theme. Do not add a `[theme]`
table to the Herdr base file. Dotbot no longer links these two files directly.
The Obsidian build fixes one upstream selector so its light palette works
without Style Settings; no palette colours are changed.

Set `dotfiles.desktopTheme.obsidianVaults` to vault paths relative to your home
directory (currently `[ "Documents/Notes" ]`). Home Manager installs the theme
in each listed vault. Activation merges only `cssTheme` and light/dark `theme`
into `.obsidian/appearance.json`, preserving fonts, snippets, and other settings.
The first change saves `appearance.json.before-desktop-theme` alongside it.
An existing theme directory with different contents is not overwritten; Home
Manager will report the collision. Set the list to `[]` to stop managing vaults;
this does not restore their previous appearance settings automatically.

Check the selected theme and the vault updater without activating anything:

```sh
nix build --no-link .#checks.x86_64-linux.desktop-theme
```

## Motion

`appearance.lua` opts into brief, restrained animations rather than Hyprland's
defaults: windows open from 95% size over 180ms and close to 97% over 120ms,
with a strong ease-out and an opacity fade. Shell surfaces only fade
(160ms in, 120ms out). There is no bounce, workspace slide, animated scrolling,
resize easing, delayed focus feedback, or decorative border rotation.

Workspace navigation and Vicinae stay instant. Hyprland's window animation
settings do not distinguish keyboard launches/closes from mouse actions, so
both use the same short transition. For motion-free windows, set `enabled = false`
on `windowsIn`, `windowsOut`, `fadeIn`, and `fadeOut`. Reload with Super+Shift+R.

## Files

- `hyprland.lua`: entry point and monitors.
- `appearance.lua`: scrolling layout, spacing, borders, input, and motion.
- `bindings.lua`: shortcuts.
- `rules.lua`: floating utility windows.
- `../quickshell/Theme.qml`: sidebar width, colors, and font.
- `../quickshell/Sidebar.qml`: sidebar layout and application launchers.
- `../quickshell/NotificationPopups.qml`: popup stack, timers, and transitions.
- `../quickshell/NotificationCard.qml`: the shared notification card.
- `../quickshell/AudioPanel.qml`: the sidebar audio popover.
- `../quickshell/AudioRow.qml`: one device or application row in the popover.
- `../quickshell/dev.qml`: isolated preview entry point for panel work.
- `../bin/qs-preview`: preview-and-screenshot helper for shell development.
- `../nix/machines/scylla/hyprland.nix`: packages, portals, UWSM environment,
  and session services.

The sidebar reuses Dolphin, PipeWire, KWallet, KDE authentication prompts, and
KDE file dialogs. No network applet is started on this wired desktop. Vicinae
and other existing XDG autostart apps are started by UWSM. KDE's
display/window-management settings do not configure Hyprland; edit the Lua
configuration instead.

Vicinae uses software rendering on this host to avoid a Qt OpenGL initialization
crash when its Wayland window opens. The override affects only Vicinae.

Print Screen selects a region and opens Satty. Press Enter to copy the result,
save it under `~/Pictures/Screenshots/`, and close the editor. Escape during
region selection cancels the capture.

Tray icons support left-click activation, right-click menus, middle-click
secondary actions, and scrolling. The bell toggles the notification list.
Cards show the app icon (or its initial), any attached image, and a progress
bar when the sender supplies a value; clicking a card runs its default action,
and other actions appear as buttons. Popups use the sender's timeout, or six
seconds when unspecified, and the countdown pauses while the pointer is over a
card. Critical and explicitly persistent notifications stay until dismissed.
Explicitly timed and transient notifications expire; other notifications remain
in the list until dismissed or withdrawn by their sender. Cards fade and scale
in and out; the list is not persisted across a shell restart.

## Shell development

Edit `quickshell/*.qml` and reload with Super+Ctrl+R
(`systemctl --user restart quickshell`). The files are symlinked from this
repository, so QML changes need no rebuild. Quickshell prints QML warnings and
errors to the service journal:

```sh
journalctl --user -u quickshell -f
```

Iterate on the audio panel without touching the live sidebar. `qs-preview`
starts a separate Quickshell instance from `quickshell/dev.qml`, waits for the
panel to map, screenshots the focused monitor, and stops the instance:

```sh
qs-preview --crop 345:420:255:45   # prints the screenshot path
qs-preview --keep                  # leave it running; tail -f /tmp/qs-dev.log
```

Because it is a separate process, a broken panel cannot take down
`quickshell.service`. `dev.qml` opens the panel on a short timer (Quickshell
does not map a fullscreen overlay created at startup) and keeps a one-pixel
anchor surface beside it. To attach a QML debugger, run the preview command
directly with `quickshell -p ~/.config/quickshell/dev.qml --debug 1234:1234
--waitfordebug`. The helper needs `grim` and `ffmpeg`; both are already present
on the Hyprland host.

## Troubleshooting

Inside the Hyprland session:

```sh
hyprctl configerrors
systemctl --user status quickshell hyprland-polkit
journalctl --user -u quickshell -b
systemctl --user restart quickshell
```

Screen sharing uses the Hyprland portal; file selection uses KDE's portal.
Verify Discord sharing and Sunshine capture after logging into the real
session. A nested compositor check does not verify those integrations or PAM
wallet unlocking.
