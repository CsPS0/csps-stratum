# Top bar for the laptop (KDE Plasma 6)

Makes the laptop's top panel look like the Windows YASB bar ([`../yasb/`](../yasb/)), and both
panels like the Windows bar and dock: black, rounded, with a thin grey border.

```
WezTerm  ♫ Track ⏮⏯⏭ ▁▃▅▂  CPU 3%  RAM 28%  GPU 2%  ☁ 1°C     2026-11-27 23:10  04 Dec 07:30 Event [  >_  ⚙]     Claude 11% used  tray  ⏻
```

| Widget | Shows | Data |
|---|---|---|
| `org.csps.appname` | The focused app's name, or `Desktop` | KDE's task manager model |
| `org.csps.media` | The current player's track, ⏮ ⏯ ⏭, a 12-bar visualizer; hidden without a player | Plasma's MPRIS model; levels from `cava-levels.py` |
| `org.csps.stats` | `CPU n%  RAM n%  GPU n%` and the weather | ksystemstats every 2 s; [wttr.in](https://wttr.in) every 30 min (located by IP; hover for the place) |
| `org.csps.nextevent` | The next event, with the Windows widget's rules (`14:00  Title`, `tomorrow 09:00  …`, `now  …`); hover for the next 8 | The clock's calendar plugins (`pimevents`: Akonadi, which syncs Google Calendar), 30 days ahead |
| `org.csps.quickapps` | Dolphin, WezTerm, System Monitor and System Settings as glyphs in a grey pill | — |
| `org.csps.power` | ⏻; click opens the leave screen | `org.kde.LogoutPrompt.promptAll` |

There is no launcher on the bar, as on Windows. `--layout` sets **Meta** to open KRunner instead
(`kwinrc [ModifierOnlyShortcuts] Meta=org.kde.krunner,/App,,toggleDisplay`), the counterpart of the
Windows key opening the search-only Start menu.

All text is JetBrainsMono Nerd Font 13 px, in the YASB colours. The clock is KDE's own (it keeps
its calendar popup with the Google events), set to JetBrains Mono and the date to `yyyy-MM-dd`. It scales its text to the panel
height, so it is slightly larger than the rest.

## Plasma style

`plasma-style/panel-background.svg` is the panel background:
- Opaque black, with 10 px corners and a 1 px `#2A2B2D` border (`--bar-outline` in YASB).
- 3 px content margins at the top and bottom, 8 px at the ends.

`--style` copies the installed WhiteSur-dark-mono to `~/.local/share/plasma/desktoptheme/OLED-Monochrome`,
swaps in this background and applies it. Everything else (popups, tooltips, colours) stays
WhiteSur's. WhiteSur's own panel is 45% black with a faint white edge, so on a black wallpaper its
corners didn't show.

## Visualizer

`cava-levels.py` runs [cava](https://github.com/karlstav/cava) and serves its latest frame on
`127.0.0.1:47836`:
- The widget asks about 20 times a second, only while a player is playing, and starts the helper
  when it doesn't answer.
- About 5 s after playback stops, the helper stops cava and exits.
- Without cava the bars stay flat. Install it with `sudo pacman -S cava`.
- `python3 cava-levels.py --self-test` checks the frame parsing and the idle exit.

## Install

```sh
cd ~/REPOS/csps-stratum && git pull --ff-only
strata/40-apps/kde-bar/install-kde-bar.sh --dry-run --style --layout   # preview
strata/40-apps/kde-bar/install-kde-bar.sh --style --layout
```

- **Without flags:** installs or updates the widgets and the helper. Restart plasmashell
  afterwards (`systemctl --user restart plasma-plasmashell`), since Plasma caches loaded widgets.
- **`--style`:** backs up `~/.config/plasmarc` and applies the style.
- **`--layout`:** backs up `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, then:
  - removes the launcher, the pager, the stock media player and Quick Launch from the top panel;
  - adds the widgets and sets the clock's font and `yyyy-MM-dd` date;
  - backs up `~/.config/kwinrc` and sets Meta to open KRunner;
  - with plasmashell stopped, puts everything in the Windows order;
  - leaves other widgets in place after the tray.
- **Needs:** `kpackagetool6`, `qdbus6`, `python3`, WhiteSur-dark-mono (for `--style`) and `cava`
  (for the visualizer).

## Undo

- **Style:** `plasma-apply-desktoptheme WhiteSur-dark-mono`.
- **Meta:** copy `kwinrc.<time>.bak` back, then `qdbus6 org.kde.KWin /KWin reconfigure`.
- **Layout:** stop plasmashell (`systemctl --user stop plasma-plasmashell`), copy the
  `plasma-org.kde.plasma.desktop-appletsrc.<time>.bak` back, and start it again.

## Cost

Measured on the laptop (i5-7440HQ with HD 630, 27 November 2026, 20 s samples):
- **Nothing playing:** plasmashell 2.0% of one core, the same as before these widgets (that is the
  OLED Span wallpaper at 15 fps). The stats (every 2 s) and the weather (every 30 min) don't show.
- **While playing:** plasmashell 3.9%, cava 1.0%, the helper 1.0%, so about 4% more of one core.
  It stops a few seconds after playback stops.
