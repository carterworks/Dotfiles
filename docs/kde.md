# KDE

`kde/` holds the KDE settings scylla should have and nothing else: shortcuts,
window manager behavior, the panel and desktop layout, power and lock-screen
choices, and a few application view settings. KDE writes application state
into the same files it reads its settings from (recently opened documents,
window and dialog sizes, splitter positions, migration markers, device and
monitor identifiers), and the repository is public, so none of that belongs
here.

## How the files reach scylla

Nothing in `~/.config` links into `kde/`. When these files were links, every
KDE program wrote its state straight into the checkout, which is how a list of
recently opened private documents reached GitHub. Instead, the `kdeConfig`
activation in `nix/hosts/scylla/home.nix` runs
`nix/hosts/scylla/apply-kde-config.py` on every `./install`, in one of two
modes:

| Mode | Files | What it does |
| --- | --- | --- |
| merge | `arkrc`, `baloofileinformationrc`, `dolphinrc`, `gwenviewrc`, `kded5rc`, `kglobalshortcutsrc`, `kscreenlockerrc`, `kwalletrc`, `kwinrc`, `okularpartrc`, `okularrc`, `plasma-localerc`, `powerdevilrc`, `xdg-desktop-portal-kderc` | Sets every key the repository file lists in the live file and leaves every other key alone, so the repository file holds only the keys that matter. |
| seed | `kactivitymanagerdrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`, `local-share/user-places.xbel` | Writes the file only when the live one is missing. These are whole layouts, numbered by Plasma, and merging keys into a different layout would add a second panel. |

Two more files are handled elsewhere. `kde/kdeglobals` is the base that
`desktopThemeKde` (`nix/modules/home/desktop-theme/`) starts from when
`~/.config/kdeglobals` is missing; the theme then writes its own colors, so
the base has none. The color schemes in `kde/local-share/color-schemes/` are
still links, because KDE never writes to them.

The activation runs before Home Manager's `linkGeneration`. If a live file is
still a link from an older generation, the script replaces the link with a
plain file holding what the link pointed at, and never writes through it, so
Home Manager leaves the file in place (it warns `does not link into a Home
Manager generation`) instead of deleting it.

`kde/.gitignore` ignores everything, so a KDE file written into the checkout
by mistake shows up nowhere in `git status`. Add a new file with `git add -f`.

## Changing a setting

1. Change it in System Settings or the program, as usual. The change stays on
   scylla only.
2. To keep it, find the key in the live file (for example
   `grep -n FocusPolicy ~/.config/kwinrc`) and copy that line, with its
   `[Group]` header, into the file in `kde/`. Copy only the setting, never a
   history, size, position, timestamp or identifier.
3. For a merged file that is new to the repository, add its name to
   `kdeMergedFiles` in `nix/hosts/scylla/home.nix`.
4. Run `./install`.

Removing a key from a merged file stops enforcing it; it does not remove the
key from the live file.

`kglobalshortcutsrc` lists only shortcuts that differ from KDE's defaults.
Each line is `action=active,default,description`, and a line whose active and
default shortcuts match carries no setting.

## What was dropped

The repository no longer tracks `KDE/UserFeedback.conf`, `baloofilerc`,
`bluedevilglobalrc`, `drkonqirc`, `kactivitymanagerd-statsrc`,
`kconf_updaterc`, `kded6rc`, `kdedefaults/`, `khelpcenterrc`, `kio_fishrc`,
`kiorc`, `ksmserverrc`, `ktimezonedrc`, `kwinoutputconfig.json`,
`kwinrulesrc`, `plasmanotifyrc`, `plasmaparc`, `plasmarc`,
`powermanagementprofilesrc`, `spectaclerc`, `systemmonitorrc` and `trashrc`.
Each held only state, a default value, or something KDE derives on its own:
`kdedefaults/` is regenerated from the global theme, `ktimezonedrc` from the
system time zone, and `kwinoutputconfig.json` holds the monitors' EDID
identifiers, so a fresh profile gets its display layout from KWin rather than
from the repository.

`kded5rc` stays, with the name it has always had: KDE Frameworks 6's `kded6`
still reads `kded5rc`.
