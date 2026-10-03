# Hyprland + Miasma sidebar

Hyprland uses its built-in **scrolling** layout: windows occupy columns on a
horizontal strip. Quickshell provides a 250 px sidebar, window/workspace lists,
launchers, audio, media controls, system tray, notifications, and the
`assets/wallpapers/01-miasma.jpg` background.

Lucide icons, compact pinned app buttons, flat window rows, and bottom-centered
workspace dots follow the Arc sidebar layout. A filled dot marks the active
space; click any outlined dot to switch to it. The speaker button reveals
audio controls. Tray icons retain the icons supplied by their applications.

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

## Files

- `hyprland.lua`: entry point and monitors.
- `appearance.lua`: scrolling layout, spacing, borders, and input.
- `bindings.lua`: shortcuts.
- `rules.lua`: floating utility windows.
- `../quickshell/Theme.qml`: sidebar width, colors, and font.
- `../quickshell/Sidebar.qml`: sidebar layout and application launchers.
- `../nix/machines/scylla/hyprland.nix`: packages, portals, UWSM environment,
  and session services.

The sidebar reuses Dolphin, System Settings, KDE Connect, PipeWire, KWallet,
KDE authentication prompts, and KDE file dialogs. NetworkManager's standalone
tray applet supplies networking because the Plasma network widget cannot run
inside Quickshell. Vicinae and other existing XDG autostart apps are started by
UWSM. KDE's display/window-management settings do not configure Hyprland; edit
the Lua configuration instead.

Vicinae uses software rendering on this host to avoid a Qt OpenGL initialization
crash when its Wayland window opens. The override affects only Vicinae.

Print Screen selects a region and opens Satty. Press Enter to copy the result,
save it under `~/Pictures/Screenshots/`, and close the editor. Escape during
region selection cancels the capture.

Tray icons support left-click activation, right-click menus, middle-click
secondary actions, and scrolling. The bell toggles the notification list;
popups use the sender's timeout, or six seconds when unspecified. Critical
and explicitly persistent popups stay until dismissed. Explicitly timed and
transient notifications expire; other notifications remain in the list until
dismissed or withdrawn by their sender. The list is not persisted across a
shell restart.

## Troubleshooting

Inside the Hyprland session:

```sh
hyprctl configerrors
systemctl --user status quickshell hyprland-polkit hyprland-network
journalctl --user -u quickshell -b
systemctl --user restart quickshell
```

Screen sharing uses the Hyprland portal; file selection uses KDE's portal.
Verify Discord sharing and Sunshine capture after logging into the real
session. A nested compositor check does not verify those integrations or PAM
wallet unlocking.
