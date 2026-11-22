# Dock for the laptop (KDE Plasma 6)

The laptop's bottom panel uses this small dock widget instead of KDE's icon-only task manager, to
match the Windows dock (Windhawk `taskbar-dock-animation`):

- **Hover magnification:** the icon under the mouse grows to 130 % (`maxScale`), its neighbours less,
  with a smooth falloff, as on macOS and the Windows dock.
- **Bounce** when an app is launched from the dock.
- **Running apps** get a dot underneath; the active window's dot is wider.
- **Dividers:** a thin line after each group of pinned apps listed in the `dividers` setting (the
  laptop: general use | chat and media | development | gaming), and one between pinned apps and
  unpinned running apps. Pinned apps stay in their pinned order even when they're running (KDE's
  model would otherwise leave a window open since login wherever it first appeared).
- **Clicks:**
  - Left click launches the app, or activates and minimises its window.
  - Middle click opens a new window.
  - Right click opens a menu with New Window, Pin to / Unpin from Dock, and Close.
- **Pinned apps** use the same list as KDE's task manager (`launchers=applications:….desktop`), so
  switching back and forth keeps them.

Why a separate widget: in Plasma 6, KDE's task manager has its QML compiled into the applet together
with its private C++ code, so it can't be copied and patched. This one uses KDE's public task model
(`org.kde.taskmanager`).

**Not included** (KDE's task manager has these):

- window thumbnails on hover
- jump lists and recent documents
- media controls
- audio and progress badges
- grouped-window popups
- drag-to-reorder

| File | Purpose |
|---|---|
| `plasmoid/org.csps.dock/` | The widget (QML only) |
| `install-kde-dock.sh` | Installs or updates it; `--replace` swaps it in for KDE's task manager on the bottom panel, `--restore` swaps back. Both keep the pinned apps and back up `plasma-org.kde.plasma.desktop-appletsrc` first. `--dry-run` previews. |

## Install

```sh
cd ~/REPOS/csps-stratum && git pull --ff-only
strata/40-apps/kde-dock/install-kde-dock.sh --dry-run --replace   # preview
strata/40-apps/kde-dock/install-kde-dock.sh --replace
```

After changing the QML, run the script without flags and restart plasmashell
(`systemctl --user restart plasma-plasmashell`); Plasma caches loaded widgets.

To go back to KDE's dock: `install-kde-dock.sh --restore`.
