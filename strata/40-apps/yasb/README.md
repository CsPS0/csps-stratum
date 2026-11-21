# YASB top bar (Windows)

A macOS / KDE-style top bar for the Windows desktop, styled with the same OLED Monochrome palette
as the rest of the setup (black, `#E6E6E6` text, `#686B6F` accent). [YASB](https://github.com/amnweb/yasb)
is a status bar written in Python and Qt. Its left end on every screen is drawn by `menubar.exe`,
a small native program in this folder.

| File | Deploys to (Windows) | Purpose |
|---|---|---|
| `config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` | Bars and widgets |
| `styles.css` | `%USERPROFILE%\.config\yasb\styles.css` | Monochrome colours (YASB's default stylesheet, recoloured) |
| `menubar/menubar.cpp` | built to `%USERPROFILE%\.config\yasb\menubar\menubar.exe` | The one-line app menu |
| `menubar/menubar.ini` | `%USERPROFILE%\.config\yasb\menubar\` | Which menus each app gets |
| `menubar/Build-MenuBar.ps1` | — | Builds and installs the two above (`-WhatIf`, `-Autostart`) |
| `calendar/next-event.py` | `%USERPROFILE%\.config\yasb\calendar\` | Next Google Calendar event for the bar |

## Layout

- **Left, every screen (menubar.exe):** `[Windows logo]  App name  File  Edit  View  Go  Window`,
  one line like macOS, following whichever app has focus. As on macOS, the screen without the
  focused app shows the same menus dimmed; they still work when clicked.
- **Main screen, centre (YASB):** date and time (click for the calendar), then the next Google
  Calendar event, e.g. `14:00  Standup` (hover: the next few events; click: opens Google Calendar).
  See *Next calendar event* below. These two sit in `centre-bar`, a 560 px bar of their own pinned
  to the exact middle of the screen and drawn over the main bar. YASB centres the main bar's middle
  section only within its share of the bar, and the right side is much wider than the left.
- **Main screen, right (YASB):** Claude usage, memory, system tray (with network),
  keyboard layout, microphone, volume, notifications. Every tray icon is always shown in the bar
  (no arrow or popup).
  - **Claude usage:** Claude Code's 5-hour limit (right-click: 7-day); click for reset times. Reads
    Claude Code's own sign-in (`~/.claude/.credentials.json`), no setup.
  - **Keyboard layout:** click to switch layouts.
  - **Microphone:** click to mute, scroll for level, middle-click for devices.
  - Tried and removed: weather (needs your location), the Quick Launch search (unreliable) and
    now playing (wrong titles, couldn't reliably pause).
- **Other screen (YASB):** date and time in the centre (the left end is the menu bar, as above).
- No power button: shutdown, restart and sleep are in the Windows logo menu.
- Solid black, no blur or animation, 30 px tall. YASB reserves the space, so maximised windows stay
  below it. Full-screen apps cover the bar (it isn't always on top), and the menu bar hides itself.
- The dock's own tray and clock are hidden (rule 25 of the taskbar styler in
  `strata/40-apps/windhawk/mods-settings.reg`, zero width rather than collapsed so LiquidGlass2 still
  centres the dock), so the dock holds apps only. The tray-tweaks mod is disabled for the same reason.

## The one-line menu (menubar.exe)

Windows apps keep their real menus inside their own windows, so the bar can't read them the way
KDE's global menu does. `menubar.exe` shows menus defined in `menubar.ini` instead. Picking an
item refocuses the app and sends its normal keyboard shortcut (or a minimise / maximise / close command).

- **Windows logo:** About this PC, Settings, Task Manager, Start menu, Sleep, Restart, Shut Down,
  Lock, Sign Out (restart, shut down and sign out ask first).
- **App name (bold):** Hide (minimise) and Quit (close).
- **App menus:** File Explorer gets File, Edit, View and Go. The desktop, Brave, VS Code
  Insiders and Zed get smaller sets; every app also gets a Window menu (minimise, maximise, its own
  menu bar via F10). Apps not listed show their name and the Window menu.
- Right-click the bar for **Edit menus** (opens `menubar.ini`), **Reload menus** and **Quit**.
- Plain Win32 C++ with no runtime: about 2.6 MB of memory. It follows focus through a Windows
  event hook, so it does no polling.
- **Bar guard:** if something focuses Windows' desktop window (the Komorebi tiling manager did this
  on empty workspaces while it was tried here), Windows minimises the YASB bars and this menu bar.
  `menubar.exe` listens for minimise events on those windows and restores them straight away.
  Without it the bars stay minimised until YASB restarts.

## Next calendar event

YASB's own calendar can only show public holidays, so `calendar/next-event.py` feeds a Custom
widget instead. Every 5 minutes it reads your calendar's private iCal link, and the bar shows the
next event within 30 days (`now`, `14:00`, `tomorrow 09:00`, `Mon 18:00`, `04 Dec 07:30` when
it's over a week away; all-day events show just the day). Nothing shows while there's no link or
nothing coming up.

1. Google Calendar → Settings → your calendar → **Integrate calendar** → copy **Secret address in
   iCal format**.
2. Put it in `%USERPROFILE%\.config\yasb\calendar-url.txt` (one link per line for several calendars).

The link gives read access to the calendar, so it stays in that local file only. `calendar-url.txt`
and the cached download `.calendar-cache.ics` are in `.gitignore`. The script uses only Python's
standard library, runs windowless (`pythonw`), and reads time zones from the calendar file itself,
since Windows Python has no time-zone database. Recurring events (daily / weekly / monthly / yearly,
intervals, counts, end dates, "2nd Tuesday"), deleted and moved occurrences, cancelled events and
all-day events are handled.

## Install

```powershell
winget install --id AmN.yasb --exact
Copy-Item .\strata\40-apps\yasb\config.yaml, .\strata\40-apps\yasb\styles.css "$HOME\.config\yasb\" -WhatIf   # drop -WhatIf to copy
.\strata\40-apps\yasb\menubar\Build-MenuBar.ps1 -Autostart   # needs the Visual C++ build tools
yasbc reload
yasbc enable-autostart   # start YASB with Windows
```

YASB reloads by itself when either file changes (`watch_config`, `watch_stylesheet`).

## Why YASB

YASB was measured against Droptop Four (a Rainmeter skin) on this desktop. The figure is idle
private memory, which is what Task Manager shows as "Memory":

| Bar | Memory |
|---|---|
| YASB 2.0.8, this config | about 73 MB |
| Droptop Four 4.420.59 on Rainmeter 4.5.28, default setup | about 132 MB |

Seelen UI wasn't measured: it runs on WebView2 (a browser engine) and replaces the dock too.

Note: the tray widget gets its icons by hooking Explorer's notification area (YASB injects into
`explorer.exe`).
