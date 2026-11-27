# Laptop top bar and dock like Windows (design)

Date: 2026-11-27. Approved in conversation ("Build it").

## Intent

The laptop's KDE Plasma 6 panels should look like, and show the same things as, the Windows YASB top
bar and Windhawk dock (`docs/screenshots/windows-top-bar.png`, `windows-dock.png`).

## Goals

- **Both panels:** black, rounded (10 px), with a 1 px `#2A2B2D` border, floating, as on Windows.
- **Top bar, left:** Arch launcher logo, the active app's name, the global menu, the playing track
  with previous / play-pause / next and a small visualizer, then `CPU n% RAM n% GPU n%` and the weather.
- **Top bar, centre:** date and time, the next calendar event, a quick-apps glyph pill (Dolphin,
  WezTerm, System Monitor, System Settings).
- **Top bar, right:** the AI usage widget, the system tray, and a power button that opens KDE's
  leave screen.
- **Text:** JetBrains Mono Nerd Font, `#E6E6E6`, like YASB.

## Non-goals and anti-goals

- No layout change to the dock beyond the border.
- No AUR widgets and no compiled code: QML plasmoids and small scripts in the repo, like
  `kde-dock` and `ai-usage`.
- No secrets in the repo; no polling faster than the Windows bar (2 s for stats, 30 min for weather).
- The pager goes (Windows has none).

## Constraints

- Plasma draws panel backgrounds from the Plasma style, so the rounding and border come from a
  user-local Plasma style.
- `plasma-org.kde.plasma.desktop-appletsrc` is edited only while plasmashell is stopped, after a
  timestamped backup. Scripts get `--dry-run`.
- The visualizer needs `cava` (`sudo pacman -S cava`, done by the user). Without it, it stays flat.
- Battery: the stats and visualizer cost CPU; the visualizer runs only while a player is playing.

## Approaches

1. **Custom QML widgets plus a Plasma style override (picked).** One look and font, no AUR, data
   from public KDE QML modules (task manager, ksysguard sensors, Plasma calendar, mpris).
2. Stock KDE widgets (system monitor text faces, weather, media controller) plus AUR ones (window
   title, Kurve). Faster to set up, but mixed fonts and looks, AUR dependencies, and the weather
   widget needs a manually picked station.
3. Draw the bar entirely inside one big widget on a transparent panel. Plasma 6 panels can't be
   fully transparent, so the theme background would still show.

## Decided (builder's calls, stated to the user)

- **Data sources:**
  - App name: the task manager model's active task.
  - Media: Plasma's mpris module.
  - Stats: ksysguard sensors `cpu/all/usage`, memory, `gpu/all/usage`.
  - Weather: wttr.in (`?format=j1`), which locates by IP in one call, as the laptop's WezTerm
    already does. Open-Meteo would need a second geo-IP service.
  - Visualizer: `cava`, run by a small Python helper that serves the latest bar levels on
    127.0.0.1. The widget polls it about 20 times a second while a player is playing, and the
    helper stops cava and exits when nobody asks.
  - Next event: the Plasma calendar event plugins (Akonadi, already syncing Google). If that can't
    be used from a plasmoid, use `yasb/calendar/next-event.py` with a link file the user creates.
- **Power:** a button that calls the leave screen (`org.kde.LogoutPrompt`).
- **New repo parts:** `strata/40-apps/kde-bar/` (plasmoids, Plasma style, install script) and docs
  updates (`hosts/laptop/README.md`, root README, screenshots).

## Changed while building

- **Quick apps:** KDE's Quick Launch showed blank icons, so a glyph pill (`org.csps.quickapps`)
  copies the Windows `quick_apps` widget instead.
- **AI usage label:** set to JetBrains Mono like the rest of the bar.
- **Clock:** KDE's clock stays, for its calendar popup. It scales its text to the panel height, so
  it is a little larger than the rest.
