# KDE

Scylla runs Hyprland. What it uses from KDE is its applications (Dolphin,
Okular, Gwenview, Ark), the KDE file dialog through the portal, KWallet,
`kded6` when an application starts it, and `kdeglobals` through the KDE Qt
platform theme. `kde/` holds settings for those and nothing else: no KWin,
Plasma shell, global shortcut, activity, power or lock-screen settings, which
only the Plasma fallback session reads. KDE also writes application state into
the files it reads its settings from (recently opened documents, window and
dialog sizes, splitter positions, migration markers, device and monitor
identifiers), and the repository is public, so none of that belongs here.

## How the files reach scylla

Nothing in `~/.config` links into `kde/`. When these files were links, every
KDE program wrote its state straight into the checkout, which is how a list of
recently opened private documents reached GitHub. Instead, the `kdeConfig`
activation in `nix/hosts/scylla/home.nix` runs
`nix/hosts/scylla/apply-kde-config.py` on every `./install`, in one of two
modes:

| Mode | Files | What it does |
| --- | --- | --- |
| merge | `arkrc`, `baloofileinformationrc`, `dolphinrc`, `gwenviewrc`, `kded5rc`, `kwalletrc`, `okularpartrc`, `okularrc`, `xdg-desktop-portal-kderc` | Sets every key the repository file lists in the live file and leaves every other key alone, so the repository file holds only the keys that matter. |
| seed | `local-share/user-places.xbel` | Writes the file only when the live one is missing. Dolphin and the file dialog keep their places in it, and KDE adds every mounted device to it. |

`kde/kdeglobals` is handled elsewhere: it is the base that `desktopThemeKde`
(`nix/modules/home/desktop-theme/`) starts from when `~/.config/kdeglobals` is
missing, and the theme then writes its own colors, so the base has none.

The activation runs before Home Manager's `linkGeneration`. If a live file is
still a link from an older generation, the script replaces the link with a
plain file holding what the link pointed at, and never writes through it, so
Home Manager leaves the file in place (it warns `does not link into a Home
Manager generation`) instead of deleting it.

`kde/.gitignore` ignores everything, so a KDE file written into the checkout
by mistake shows up nowhere in `git status`. Add a new file with `git add -f`.

## Changing a setting

1. Change it in the program, as usual. The change stays on scylla only.
2. To keep it, find the key in the live file (for example
   `grep -n MenuBar ~/.config/dolphinrc`) and copy that line, with its
   `[Group]` header, into the file in `kde/`. Copy only the setting, never a
   history, size, position, timestamp or identifier.
3. For a merged file that is new to the repository, add its name to
   `kdeMergedFiles` in `nix/hosts/scylla/home.nix`.
4. Run `./install`.

Removing a key from a merged file stops enforcing it; it does not remove the
key from the live file.

`kded5rc` keeps the name it has always had: KDE Frameworks 6's `kded6` still
reads `kded5rc`. It stops `kded6` from mounting devices on its own.

## What was dropped

The Plasma session's files are gone: `kwinrc`, `kwinoutputconfig.json`,
`kwinrulesrc`, `kglobalshortcutsrc`, `plasma-org.kde.plasma.desktop-appletsrc`,
`plasmashellrc`, `plasmarc`, `kactivitymanagerdrc`,
`kactivitymanagerd-statsrc`, `kscreenlockerrc`, `ksmserverrc`,
`powerdevilrc`, `powermanagementprofilesrc`, `plasma-localerc`,
`plasmanotifyrc`, `kdedefaults/` and the unused Cosmic color schemes. So are
files that held only state or a default value: `KDE/UserFeedback.conf`,
`baloofilerc`, `bluedevilglobalrc`, `drkonqirc`, `kconf_updaterc`,
`kded6rc`, `khelpcenterrc`, `kio_fishrc`, `kiorc`, `ktimezonedrc`,
`plasmaparc`, `spectaclerc`, `systemmonitorrc` and `trashrc`.

Scylla keeps all of them: step 1 of
[the history rewrite](history-rewrite.md#steps) copies the live files out of
the checkout before the change reaches it, so the Plasma fallback session
keeps its panel, shortcuts, display modes and HDR settings, outside Git. A new
profile's Plasma session starts from KDE's defaults.
