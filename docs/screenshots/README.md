# Screenshots

Reference shots of the finished **OLED Monochrome** setup, taken with no windows on screen
(Windows: Show Desktop). Windows shots: 25 November 2026 (the search-only Start menu: 22 November);
laptop: 27 November 2026; phone: 22 November 2026. Wallpaper: [OLED Span](../../strata/40-apps/oled-span/) (contours style) everywhere;
it only draws greys. Use them to check a rebuild (the
[`INSTALL-WITH-AI.md`](../../INSTALL-WITH-AI.md) prompt tells the agent to compare against them).

Taking them with an agent: the Claude desktop app draws a warm glowing frame around the main screen
while it controls the screen, and it stays for the rest of that turn, so capture in a turn that
hasn't used screen control (and check the edges are pure black).

## Windows 11 desktop

| File | What it shows |
|---|---|
| [`windows-desktop.png`](windows-desktop.png) | Main monitor: the floating YASB top bar (app name and paused player with its visualizer from `menubar.exe`; CPU, RAM, GPU and weather; centred clock and quick icons; Claude usage, tray, power); the Windhawk dock with grouped, monochrome icons. |
| [`windows-top-bar.png`](windows-top-bar.png) | The top bar on its own (1920x44: the bar floats 6 px from the edges). |
| [`windows-dock.png`](windows-dock.png) | The dock on its own: separators between app groups, running dots. |
| [`windows-start-search.png`](windows-start-search.png) | The search-only Start menu: black pane, dark grey field, monochrome search glyph. |
| [`windows-second-screen.png`](windows-second-screen.png) | Second monitor (16:10): the same top bar with every widget, tray included. |

Setup: [`strata/40-apps/windhawk/`](../../strata/40-apps/windhawk/), [`strata/40-apps/yasb/`](../../strata/40-apps/yasb/),
[`strata/10-os/windows/`](../../strata/10-os/windows/).

## Laptop (Arch Linux, KDE Plasma 6)

| File | What it shows |
|---|---|
| [`laptop-desktop.png`](laptop-desktop.png) | The rounded, bordered top bar laid out like Windows (focused app name, playing track with visualizer, CPU / RAM / GPU and weather; centred `yyyy-MM-dd` clock and quick-app glyphs; Claude usage, tray, power), and the bordered dock with group dividers. |
| [`laptop-top-panel.png`](laptop-top-panel.png) | The top bar on its own (1920x48: the panel floats a few pixels from the edges). |
| [`laptop-dock.png`](laptop-dock.png) | The dock on its own. |

Setup: [`hosts/laptop/`](../../hosts/laptop/), [`strata/40-apps/kde-bar/`](../../strata/40-apps/kde-bar/),
[`strata/40-apps/kde-dock/`](../../strata/40-apps/kde-dock/), [`strata/40-apps/ai-usage/`](../../strata/40-apps/ai-usage/),
[`strata/40-apps/oled-span/`](../../strata/40-apps/oled-span/).

## Phone (Galaxy A52s, Android)

| File | What it shows |
|---|---|
| [`phone-home.png`](phone-home.png) | An empty home-screen page (1080x2400) with OLED Span playing in the Wallpaper Engine app; the strip behind the status bar is dark. |

Setup: [`strata/40-apps/oled-span/`](../../strata/40-apps/oled-span/) (`wallpaper-engine-phone`).

## Left out

The calendar-event widget was hidden on both machines while taking the shots (Windows: taken out of
the live `config.yaml`; laptop: taken off the panel, then put back with `install-kde-bar.sh --layout`),
and the laptop's desktop icons were hidden (the desktop pointed at an empty folder for the shot;
since 27 November the laptop desktop shows no icons at all), because they show personal names. The phone shot is an empty home-screen page, since the main one
shows widgets with personal details (location, account balance).
