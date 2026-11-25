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
| `../ai-usage/ai_usage.py`, `popup.py` | `%USERPROFILE%\.config\yasb\ai-usage\` | Claude and Antigravity quota used, and the click-open details |

## Layout

Both screens get the same bar (YASB's `top-bar` and `centre-bar`, `screens: ['*']`):

```
[App]  ● ○  ♪ Title ⏮ ⏸ ⏭ ▂▅▃▇  ···  CPU 5%  RAM 53%  GPU 4%  ☁ 7°  | Wed 25 Nov 15:21  next event  [▭ >_ ◔ ⚙] |  Claude 21% used  tray…  en 🎤 🔊 🔔 ⏻
└────────── menubar.exe strip ──────────┘    └──── top-bar, left ────┘ └──────── centre-bar ─────────┘    └──────────── top-bar, right ────────┘
```

- **Left, every screen (menubar.exe):** the focused app's name in bold (click: Hide / Quit),
  following whichever app has focus; the screen without the focused app shows it dimmed. The
  Windows logo menu and the app menus are switched off (`[bar] logo = 0`, `menus = 0` in
  `menubar.ini`): the power button covers the logo menu, and the app menus only existed for the
  few apps listed by hand (see below). Set either back to 1 to bring them back.
  After the name come:
  - **Virtual desktop dots**, only while there are 2 or more desktops: a pill for the current one,
    rings for the others; click one to switch to it. menubar.exe reads Explorer's list
    (`HKCU\...\Explorer\VirtualDesktops`) when it changes and switches with Ctrl+Win+Left/Right,
    since Windows has no public call for it. YASB's `windows_desktops` widget can't hide itself
    with one desktop, so it isn't used.
  - **What's playing**, whenever a player is open (playing or paused, so a paused song can be
    resumed from the bar): a note, the title, previous / play-pause / next, and while it plays a
    12-band visualizer right next to them (click the title or the bars to play / pause). With
    several players open (a song and a video), a `⌄ 2` dropdown lists each one with Play or Pause,
    its title and app, and toggles just that one; the bar itself shows whichever is playing (or,
    with all paused, Windows' current one). It comes from Windows' media controls (the ones in the
    volume flyout), followed through events. Browsers only report audible media, so a muted video
    doesn't show. The visualizer listens to what the speakers play (WASAPI loopback) only while
    something plays (flat and dim while paused); it replaced cava (uninstalled).
    The player keeps one position for muscle memory: it's anchored just left of the CPU widget, with
    a fixed-width title box (20 characters), buttons as wide as the wider of play and pause, the
    visualizer always there and room for the dropdown always kept. So ⏮ ⏯ ⏭ don't move with the
    title, the app name, play / pause, the desktop dots or the number of players; a long app name
    only shortens the title.

  The strip ends `reserve` px (`menubar.ini`, 290) before the clock bar, which keeps room for
  YASB's CPU / RAM / GPU and weather; the song title is shortened to fit. The strip hides on a screen
  while the focused app covers that whole screen (games, videos), including apps that go
  fullscreen after they take focus. It also hides on any screen with no YASB bar (YASB closed or
  not started yet), where it would otherwise sit over the top of maximised windows, and comes
  back with the bar.
- **CPU, RAM, GPU (YASB, left of the weather):** `CPU 5%  RAM 53%  GPU 4%`, every 2 s. Click for
  a small popup with a 2-minute graph and details (CPU: usage, frequency, cores; RAM: in use,
  cached, available, swap; GPU: load and temperature graphs, VRAM, power draw, fan; GPU via NVIDIA's
  NVML). Right-click switches the label (CPU frequency, RAM and VRAM used of total). These replaced
  a Task Manager shortcut: Task Manager can't be opened on a given graph (no switch, it runs
  elevated, and the selected graph isn't saved).
- **Weather (YASB, just left of the clock):** [Open-Meteo](https://open-meteo.com) icon and
  temperature (free, no account). The first time, it shows *Set up location*: click it and search
  for your city; YASB keeps it in its own `weather.json`, not in this repo. Click later for a
  compact 5-day card (small icons; the hourly strip is off because it drew see-through), right-click
  for the town name.
- **Centre (YASB):** date and time (click for the calendar), then the next Google
  Calendar event, e.g. `14:00  Standup` (hover: the next few events; click: opens Google Calendar).
  See *Next calendar event* below. These two sit in `centre-bar`, a bar of their own pinned to the
  exact middle of the screen and drawn over the main bar. YASB centres the main bar's middle
  section only within its share of the bar, and the right side is much wider than the left. The
  centre bar is only as wide as its content (`width: auto`); a fixed 560 px covered the start of
  the Claude usage once the tray grew.
- **Why two bars:** YASB GUI lists `top-bar` (the full-width floating bar with the weather and the
  right-hand widgets; it reserves the space) and `centre-bar` (the clock, next event and quick
  icons), each on every screen. The separate centre bar is what got the clock into the true
  middle; centring inside the top bar didn't. (There used to be a third, `secondary-bar`, with
  fewer widgets for the other screen.)
- **Centre, after the event:** a pill of quick icons (File Explorer, WezTerm, Task Manager, Settings).
- **Right (YASB):** Claude and Antigravity usage, system tray (with network),
  keyboard layout, microphone, volume, notifications, power. Every tray icon is always shown in
  the bar (no arrow or popup).
  - **Power:** opens `menubar.exe`'s power menu (Lock, Sleep, Restart, Shut Down, Sign Out from
    `menubar.ini` `[power]`). YASB's own power menu restarts with plain `shutdown /r`, which stops at
    the pre-sign-in screen, so it isn't used.
  - **Claude / Antigravity usage:** e.g. `Claude 37% used` (5-hour window) and `Antigravity 12% used`
    (most-used model). Click for a dropdown with every limit, its bar and reset time. Each one is
    hidden while its app is closed. Comes from [`../ai-usage/`](../ai-usage/), which the laptop's
    KDE panel uses too.
  - **Keyboard layout:** click to switch layouts.
  - **Microphone:** click to mute, scroll for level, middle-click for devices.
  - Tried and removed: weatherapi.com weather (needs an API key), the Quick Launch search
    (unreliable), YASB's now-playing widgets (media_lite showed wrong titles; media kept showing
    paused players) and cava (couldn't sit next to the player).
- **Look** (after the floating style in [this video](https://youtu.be/u7Gi1fU8LTQ), without its
  Komorebi tiling setup, kept monochrome): the bars float 6 px from the screen's top and sides,
  32 px tall, with 10 px rounded corners and a 1 px `#2A2B2D` outline; text is JetBrains Mono.
  The menu bar is drawn inside the left end, right of the rounded corner, and the centre bar inside
  the outline; `menubar.cpp` (`BAR_HEIGHT`, `BAR_GAP`, `BAR_RADIUS`) must match `config.yaml` and
  `styles.css`.
- Solid black, no blur or animation. YASB reserves the bar plus 6 px above and below it, so
  maximised windows stay 6 px below the bar. The bars are always on top, so a full-screen app left behind another window (a game
  behind Claude) doesn't cover them. While a full-screen app (a game, a video) is focused, every
  bar on its screen hides, and so does the menu bar; the other screen keeps its bar. YASB's own
  `hide_on_fullscreen` only pushes its bars to the bottom of the window stack, so `menubar.exe`
  really hides them on that screen while the full-screen app is the top window there (focused or
  not: clicking something on the other screen keeps them hidden) and shows them again afterwards.
  Click-through overlays that span the screen, such as the Claude app's, don't count. If
  `menubar.exe` is killed while it has the bars hidden, `yasbc reload` brings them back. The menu bar
  raises its strips again whenever a YASB bar reappears above them, and puts the narrow centre bar
  (date, time, next event) back above the full-width bar, which otherwise covers it after coming
  back.
- While a maximised window sits under the bar on a screen, a 1 px `#2A2A2A` line along the bottom
  of the reserved space, right above the window, separates the two (drawn by `menubar.exe`; it
  takes no space and lets clicks through).
- The dock's own tray and clock are hidden (rule 25 of the taskbar styler,
  `Visibility=Collapsed`, in `strata/40-apps/windhawk/oled-dock.reg`), so the dock holds apps only. The tray-tweaks mod is disabled for the same reason.

## The one-line menu (menubar.exe)

Windows apps keep their real menus inside their own windows, so the bar can't read them the way
KDE's global menu or macOS does; Chromium and Electron apps (Brave, VS Code, Claude) and WinUI apps
don't expose them at all. `menubar.exe` shows menus defined in `menubar.ini` instead, so only the
apps listed there got more than a Window menu. Picking an item refocuses the app and sends its
normal keyboard shortcut (or a minimise / maximise / close command). The logo and app menus are
off for now (`[bar]` in `menubar.ini`); what follows describes them when they're on.

- **Windows logo:** About this PC, Settings, Task Manager, Start menu, Sleep, Restart, Shut Down,
  Lock, Sign Out (only sign out asks first). Restart and Shut Down work like Start's: no prompt,
  and they ask for Automatic Restart Sign-On (`InitiateShutdown` with `SHUTDOWN_ARSO`), so the
  next boot should sign you back in, lock and show your own lock screen. Plain `/r` and `/s` left
  the machine at the pre-sign-in screen, which showed an old Spotlight picture instead of yours.
  Apps registered for restart (Brave with the tabs you had open) are only asked back when Windows'
  **Restart apps** setting is on (`HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon`,
  `RestartApps`, set to 0 here, which should also stop Start's restart from reopening them).
  `shutdown /g` and `/sg`, used before, always asked them back. Checked after a reboot on
  2026-11-25: the session signed in and locked (LockApp), YASB and the menu bar started from their
  tasks 15 s after boot, and Brave stayed closed. The lock screen is ignored as a focused app; it
  showed up as "LockApp.exe" after unlocking.
- **App name (bold):** Hide (minimise) and Quit (close).
- **App menus:** File Explorer gets File, Edit, View and Go. The desktop, Brave, VS Code
  Insiders and Zed get smaller sets; every app also gets a Window menu (minimise, maximise, its own
  menu bar via F10). Apps not listed show their name and the Window menu.
- Right-click the bar for **Edit menus** (opens `menubar.ini`), **Reload menus** and **Quit**.
- Plain Win32 C++ with no runtime: about 2.5 MB of memory. It follows focus and windows through
  Windows event hooks. The one exception: once a second it checks that the centre bar is still
  above the full-width bar. YASB sometimes re-tops the full-width bar without showing it again
  (closing Antigravity did it), which covered the date, time and event, and Windows sends no
  event for a stacking change alone. The check costs nothing measurable (0 ms CPU over 10 s).
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
.\strata\40-apps\yasb\menubar\Build-MenuBar.ps1 -Autostart   # needs the Visual C++ build tools and an elevated prompt
yasbc reload
yasbc enable-autostart --task   # start YASB at sign-in; elevated prompt
# don't reopen apps (Brave and its tabs) after a restart: Settings > Accounts > Sign-in options > Restart apps
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name RestartApps -Value 0 -Type DWord -WhatIf
```

Both start from sign-in scheduled tasks (`YASB Reborn`, `MenuBar`) rather than the Run key.
After a reboot on 2026-11-22, Explorer ran other Run entries but skipped YASB and the menu bar.

YASB reloads by itself when either file changes (`watch_config`, `watch_stylesheet`).

`AmN.yasb` on winget installs the official MSI from the [YASB releases](https://github.com/amnweb/yasb/releases)
(2.0.8, checked 2026-11-25). [YASB GUI](https://github.com/amnweb/yasb-gui) (0.0.7) works with this
config, but it has been discontinued since 2026-09 and is older than YASB 2.0.8. Saving from it
rewrites the whole file: it drops the comments and `label_placeholder: ''` (the three custom
widgets then show "Loading..." before their first result), and it can change `windows_app_bar` and
`update_check`. Keep `config.yaml` here as the source of truth, and copy GUI edits back by hand.

## Why YASB

YASB was measured against Droptop Four (a Rainmeter skin) on this desktop. The figure is idle
private memory, which is what Task Manager shows as "Memory":

| Bar | Memory |
|---|---|
| YASB 2.0.8, this config | about 73 MB |
| Droptop Four 4.420.59 on Rainmeter 4.5.28, default setup | about 132 MB |

Seelen UI wasn't measured: it runs on WebView2 (a browser engine) and replaces the dock too.

What it costs now (2026-11-25, private memory, CPU over 10 s while music played; both screens):

| | Memory | CPU |
|---|---|---|
| YASB (both screens, weather, quick icons, power) | 80.4 MB | about 0.2 % of one core |
| menubar.exe, nothing playing (name, dots, now playing, CPU / RAM / GPU) | about 3.5 MB | none measurable |
| menubar.exe while music plays (adds the visualizer's audio capture) | about 24 MB | about 2 % of one core |

The visualizer is the only part with a steady cost, and only while something plays: Windows'
audio capture accounts for about 20 MB (the same with a 1 s or a 100 ms buffer), and the bars
redraw 30 times a second. cava cost about 5 MB and 1–3.5 % for the same job but couldn't sit next
to the player.

Note: the tray widget gets its icons by hooking Explorer's notification area (YASB injects into
`explorer.exe`).

## Testing from the Claude app

A terminal or agent started by the Claude desktop app runs inside its packaged-app container:

- **Started processes go with it:** anything started from there (`menubar.exe` built and launched by
  hand, for example) is closed when the app closes. `Build-MenuBar.ps1` therefore starts it
  through the `MenuBar` task.
- **Registry reads can differ:** registry reads from there can see the container's own copy of
  `HKCU`. On 2026-11-25 such a shell still listed 2 virtual desktops after one was closed, while
  `menubar.exe` (started by its task) correctly read 1. Check what the bar reads by starting it
  through the task, not from that shell.
