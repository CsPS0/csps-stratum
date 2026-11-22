# Windhawk Stratum

This layer encapsulates configuration, active mods, and registry customizations for **Windhawk** (v1.7.3+) on Windows 11.

---

## Active Windhawk Mods Overview

The desktop profile uses Windhawk for an **OLED monochrome** look that mirrors the laptop's KDE Plasma `OLED_Monochrome` scheme: near-opaque black surfaces with light blur, flat 1px grey borders, and white/grey text. The dock layout from the LiquidGlass themes is kept; only their colours are overridden (see [Monochrome overrides](#monochrome-overrides)).

| Mod Identifier | Version | Purpose & Visual Role |
|---|---|---|
| `windows-11-taskbar-styler` | 1.11.2 | Draws the OLED dock with **no theme** (custom XAML styles only, [`oled-dock.reg`](oled-dock.reg)): a floating black pill (black blur fill, faint border, 18 px corners) sized to the pinned apps and centred on the screen (the dock reserves a fixed, unidentified 58 px after the last app; rules 26 and 29 offset it), macOS-style running dots, and the tray collapsed (rule 25: `Visibility=Collapsed`). It used to run the LiquidGlass2 theme, which caps the dock at screen width − 2 × (tray width + 50) and measures the tray even when hidden: with 32 pinned apps Windows then shrank every icon to fit about 1540 px. Without the theme the dock uses the whole screen width. |
| `windows-11-start-menu-styler`| 1.7 | Pairs the Start Menu with the **LiquidGlass2** glass theme. |
| `windows-11-file-explorer-styler`| 1.7.2 | Compact navigation bar (`NoCommandBar` theme) in OLED monochrome: the file list, Home and Gallery backgrounds are solid `#FF000000` and the toolbar buttons `#FF121314`. These were 85 %-black `WindhawkBlur` glass. The styler's background effect is `default` (it was `micaAlt`, a see-through wallpaper tint), so the styler leaves the backdrop alone. Translucent-windows then repaints Explorer's panels transparent and puts an opaque black backdrop behind them (rule 3 for `explorer.exe`, `FF000000`). Measured on a fresh window over a red background: `#000000` everywhere. Two combinations that don't work: the styler's `none` or `micaAlt` turns the black backdrop off, and the styler adds a faint `#191919` into the panels. Already-open windows keep their old backdrop until reopened. |
| `windows-11-notification-center-styler`| 1.8 | Harmonizes Action Center and notification popups with the translucent palette. |
| `windows-11-settings-styler`| 1.2.1 | StoreFrame11 layout (slim icon sidebar) for the Settings app, in OLED monochrome: solid black window, sidebar and title bar (dark-mode `SolidBackgroundFillColorBase`, `LayerFillColorDefault`, `ApplicationPageBackgroundThemeBrush`, caption colours → `#FF000000`), search box `#121314` with a `#35373A` outline, borders `#1E1F21`. All 16 background layers that were see-through `HostBackdrop` acrylic (window root, title bar, page, content area, sidebar) are now solid `#FF000000`, and the base colours are no longer transparent; together these were the macOS "liquid glass" look. |
| `taskbar-icon-size` | 1.3.11 | Custom height (60px), icon dimensions (35px), and button widths (44px) for dock proportions. |
| `hide-start-button` | 1.0 | Hides the default Windows 11 Start button for a streamlined dock look. |
| `taskbar-pin-layout` (local) | 1.5 | Custom mod in [`custom-mods/`](custom-mods/): pins 34 used apps (Rider via `JetBrains Rider *`, which follows its versioned updates) grouped by type (general use, chat and media, development, gaming, customizing and system) with a separator after each group (Windows only lets Explorer pin, so this runs inside it). Applies once per list change. |
| `taskbar-trailing-separator` (local) | 1.0 | Custom mod in [`custom-mods/`](custom-mods/): hides the last separator until an unpinned app is open, like the macOS Dock's divider before recent apps. |
| `taskbar-attention-bounce` (local) | 1.0 | Custom mod in [`custom-mods/`](custom-mods/): an app asking for attention keeps hopping, like on the macOS Dock, until you switch to it. Animates composition `Translation.Y`, so it stacks with `taskbar-dock-animation`'s magnification. |
| `taskbar-icon-separators` | 1.0.33 | A thin divider between pinned and unpinned apps, matching the laptop dock. The mod adds a real (inert) taskbar button, pinned right after the last pinned app; Windows always puts running unpinned apps after the pinned ones, so it splits the two. Add one by right-clicking the taskbar, then drag it into place; right-click it to remove it. Default look (grey line, brightness 168, alpha 173) already fits the monochrome palette. When no unpinned app runs, the divider sits at the end of the dock. |
| `taskbar-dock-animation` | 1.9.2 | macOS-style dock icon magnification and hover physics on taskbar items. Set to animate apps only (`ExcludeSystemButtonsMode=3`) with default spacing (`50`): on this Windows build the tray sits inside the taskbar frame (LiquidGlass2's `TrayInFrame` mode), so animating "system" elements made the tray pill grow on hover and shove the dock left. |
| `translucent-windows` | 1.8.2 | Acrylic blur behind application surfaces with a black tint (`B0000000`). Notepad, `wezterm-gui.exe` and `SystemSettings.exe` are excluded (the Settings app is solid black through `windows-11-settings-styler` instead; the blur made it look like glass). `explorer.exe` keeps the effect but with an opaque `FF000000` tint, so File Explorer is solid black. That rule applies to everything Explorer draws, so the desktop's right-click menus are solid black too, instead of dark glass. |
| `icon-resource-redirect` | 1.3 | Redirects system shell icons to the monochrome **All White Icons** set (`niivu`, from Windhawk's theme catalogue). `themePaths[0]` adds the per-app monochrome theme built by `strata/10-os/windows/dock-icons/Build-ExeIconTheme.ps1` (absolute path to your profile). Changing it prompts for an icon-cache clear and Explorer restart. |
| `taskbar-tray-system-icon-tweaks` | 1.3.2 | **Disabled.** It styled the dock's tray, which is now hidden; tray icons, clock and quick settings live in the YASB top bar (`strata/40-apps/yasb`). |
| `taskbar-thumbnail-reorder` | 1.1.5 | Reordering capability for taskbar preview thumbnails. |
| `taskbar-button-click` | 1.0.9 | Advanced mouse click handling on running apps (Ctrl+Click to close). |
| `explorer-details-better-file-sizes` | 1.6 | Human-friendly size formatting (MB/GB) in File Explorer details view. |
| `extension-change-no-warning` | 1.0.1 | Disables the redundant confirmation prompt when renaming file extensions. |

---

## Files in this Stratum

- `userprofile.json`: Canonical Windhawk active mods declaration.
- `mods-settings.reg`: Exported registry settings under `HKLM\SOFTWARE\Windhawk\Engine\Mods`.

---

## Monochrome overrides

The styler mods keep their themes for layout (`LiquidGlass2` for the Start menu, `NoCommandBar` for Explorer, `TranslucentShell` for the notification center); the taskbar has no theme and its shape comes from [`oled-dock.reg`](oled-dock.reg) (rules 25-29). On top of each theme, custom `controlStyles` / `styleConstants` recolour only the colour properties:

| Theme property | Monochrome value |
|---|---|
| Dark glass fill (`WindhawkBlur`, dark tint) | `<WindhawkBlur BlurAmount="7" TintColor="#D9000000"/>` |
| Gradient "glass edge" border / stroke | `<SolidColorBrush Color="#33FFFFFF"/>` |
| Dark hover / pressed state | `<SolidColorBrush Color="#1FFFFFFF"/>` |
| Yellow-tinted Explorer highlight gradient | `<SolidColorBrush Color="#14FFFFFF"/>` |

`monochrome/generate_overrides.py` produces these values from the installed mod sources (`C:\ProgramData\Windhawk\ModsSource`). Re-run it after a styler update changes a theme, apply the output to `HKLM\SOFTWARE\Windhawk\Engine\Mods\<mod>\Settings` (elevated), then re-export `mods-settings.reg`. The taskbar styler needs an Explorer restart to pick up the change.
