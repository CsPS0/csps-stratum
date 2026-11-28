# Laptop Top Bar Implementation Plan

> **Status, 2026-11-28:** built, then changed while using it:
> - **Launcher:** removed; Meta opens KRunner.
> - **Clock:** KDE's clock was replaced by `org.csps.clock`, fixed to `2026-11-28  00:44` (the Hungarian
>   locale gave `0:41`).
> - **Event dates:** a week or more away, they read `12-04`.
>
> The current state is in `strata/40-apps/kde-bar/README.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the laptop's KDE panels look like, and show what, the Windows YASB bar and dock do.

**Architecture:**
- A user-local Plasma style, `OLED-Monochrome`: a copy of WhiteSur-dark-mono with its own panel
  background, opaque black, radius 10, 1 px `#2A2B2D` border.
- Six small QML plasmoids (quick apps added while building) under `strata/40-apps/kde-bar/plasmoids/`.
- One install script that installs the style and plasmoids and, with `--layout`, rebuilds the top
  panel after a backup.

**Tech Stack:** QML (Plasma 6.8 plasmoids), bash, Python 3 stdlib, cava.

**Spec:** `docs/superpowers/specs/2026-11-27-laptop-top-bar-design.md`

## Global Constraints

- Plasma 6 / Qt 6 QML only; no compiled code, no AUR packages.
- Text: font `JetBrainsMono Nerd Font`, colour `#E6E6E6`; border `#2A2B2D`; corner radius 10 px.
- Polling: at most every 2000 ms for stats, 30 min for weather, 300 s for the calendar refresh,
  about 50 ms for the visualizer, and only while a player is Playing.
- `--dry-run` on every script. Back up `~/.config/plasma-org.kde.plasma.desktop-appletsrc` and
  `~/.config/plasmarc` with a timestamp before changing them. Edit AppletOrder only while
  `plasma-plasmashell.service` is stopped.
- No secrets in the repo. No commits unless the user asks.

## Review Focus

- **Nothing playing, or the player closed while playing:** the media widget takes no room and the
  helper exits.
- **cava not installed:** the visualizer shows flat bars and nothing errors in the journal.
- **Offline at login:** the weather is hidden, then appears on the next successful fetch.
- **No events in the coming days, or an all-day event:** the event label hides, or shows `All day`.
- **Desktop focused (no active window):** the app name shows `Desktop`.

---

### Task 1: Plasma style with rounded, bordered panels

**Files:**
- Create: `strata/40-apps/kde-bar/plasma-style/panel-background.svg`
  - A frame SVG with the elements `center`, `top`, `bottom`, `left`, `right`, `topleft`,
    `topright`, `bottomleft` and `bottomright`.
  - Matching `mask-*` elements, and `hint-{top,bottom}-margin` of 3 px and
    `hint-{left,right}-margin` of 8 px.
  - Corners are 10 x 10: a quarter disc of `#2A2B2D` with a radius-9 black quarter disc inside;
    edges are 1 px border plus black.
- Create: `strata/40-apps/kde-bar/install-kde-bar.sh`. This task adds the `--style` part only:
  copy `/usr/share/plasma/desktoptheme/WhiteSur-dark-mono` to
  `~/.local/share/plasma/desktoptheme/OLED-Monochrome`, rewrite the metadata Id and Name, and put
  the SVG at `widgets/panel-background.svg` with the `.svgz` removed. Then
  `plasma-apply-desktoptheme OLED-Monochrome`.

- [ ] Validate the SVG with Python `xml.etree`; every required id is present.
- [ ] Run `install-kde-bar.sh --dry-run --style` and check it lists the copy, the overlay and the
  apply.
- [ ] Run `--style` on the laptop; `plasmarc [Theme] name=OLED-Monochrome`.
- [ ] Screenshot: both panels show rounded corners with a grey 1 px border.

### Task 2: Widgets

**Files:** `strata/40-apps/kde-bar/plasmoids/<id>/metadata.json` and `contents/ui/main.qml` for
each widget. All use `Plasmoid.backgroundHints: NoBackground` and take no room while they have
nothing to show.

| Id | Shows | Source |
|---|---|---|
| `org.csps.appname` | Active app name (bold), or `Desktop` | `TaskManager.TasksModel` active task, `AppName` role |
| `org.csps.media` | ♫ track, ⏮ ⏯ ⏭, a 12-bar visualizer | `org.kde.plasma.private.mpris` `Mpris2Model.currentPlayer`; levels from `cava-levels.py` |
| `org.csps.stats` | `CPU n%  RAM n%  GPU n%  <icon> n°C` | `org.kde.ksysguard.sensors` `cpu/all/usage`, `memory/physical/usedPercent`, `gpu/all/usage` (2000 ms); `https://wttr.in/?format=j1` every 30 min |
| `org.csps.nextevent` | `14:00 Title` of the next event in the coming 7 days; tooltip with date | `org.kde.plasma.workspace.calendar` `EventPluginsManager { enabledPlugins: ["pimevents"] }` + `Calendar.daysModel.eventsForDate()` |
| `org.csps.power` | ⏻ glyph; click opens the leave screen | `qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptAll` via the executable engine |

- Create: `strata/40-apps/kde-bar/cava-levels.py`.
  - `python3 cava-levels.py [--port 47836] [--bars 12] [--self-test]`.
  - It serves `GET /` with `text/plain` levels `0..100` separated by `;`, from a cava child
    started with a generated raw-ascii config.
  - Bound to 127.0.0.1. It exits after 5 s without requests. Without cava it serves zeros.
  - The widget starts it detached when Playing (`setsid -f python3 ... >/dev/null 2>&1`).
- [ ] `python3 cava-levels.py --self-test` prints `ok` (parsing of a cava raw frame, idle exit).
- [ ] Each plasmoid installs with `kpackagetool6 -t Plasma/Applet -i/-u`, and
  `journalctl --user -u plasma-plasmashell` shows no QML errors for `org.csps.*` after a restart.

### Task 3: Top panel layout

**Files:** `install-kde-bar.sh` gains `--layout`.

- [ ] Back up `appletsrc` and `plasmarc`.
- [ ] Through `evaluateScript`, add the six widgets to the top panel and remove
  `org.kde.plasma.pager`, `org.kde.plasma.mediacontroller` and `org.kde.plasma.quicklaunch`. Set the clock's font to JetBrains
  Mono (`autoFontAndSize=false`, `fontFamily=JetBrainsMono Nerd Font`).
- [ ] Stop plasmashell and set AppletOrder to: kicker, appname, appmenu, media, stats, spacer,
  clock, nextevent, quickapps, spacer, aiusage, systray, power. Start plasmashell.
- [ ] `--dry-run --layout` prints the backup paths and the new order without changing anything.
- [ ] Screenshot compared with `docs/screenshots/windows-top-bar.png`, with a player playing and
  without.

### Task 4: Docs

- [ ] Write `strata/40-apps/kde-bar/README.md` (what, needs, install, restore).
- [ ] Update `hosts/laptop/README.md` (Plasma style row, top panel, drop the "left out on purpose"
  note) and the root README's 40-apps lists.
- [ ] Retake `docs/screenshots/laptop-*.png` and update its README.
