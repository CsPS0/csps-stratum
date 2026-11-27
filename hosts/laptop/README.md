# Laptop profile (Arch Linux, KDE Plasma 6)

The laptop's look is the original **OLED Monochrome**: pure black, greys and white, which the Windows
desktop copies. Most of it is KDE settings rather than files, listed here so it can be rebuilt.

| Part | Setting | Source |
|---|---|---|
| Colour scheme | **OLED Monochrome** | [`OLED_Monochrome.colors`](OLED_Monochrome.colors) → `~/.local/share/color-schemes/` |
| Global theme base | Breeze Dark (`org.kde.breezedark.desktop`) | KDE |
| Plasma style | **OLED Monochrome**: WhiteSur-dark-mono with a black, rounded, bordered panel background | [WhiteSur KDE](https://github.com/vinceliuice/WhiteSur-kde) install script, then [`strata/40-apps/kde-bar/`](../../strata/40-apps/kde-bar/) (`install-kde-bar.sh --style`) |
| Application style | Kvantum | `kvantum`, `kvantum-qt5` |
| Window decoration | Breeze | KDE |
| Icons | yet-another-monochrome-icon-set | AUR `yamis-icon-theme-git` |
| Cursor | Bibata Modern Classic | AUR `bibata-cursor-theme-bin` (Windows: [`strata/10-os/windows/cursors/`](../../strata/10-os/windows/cursors/)) |
| Fonts | Inter 10 (UI, 9 toolbars, 8 smallest), JetBrainsMono Nerd Font 10 (fixed) | `inter-font`, `ttf-jetbrains-mono-nerd` |
| Wallpaper | **OLED Span**, an animated black-and-white Plasma wallpaper plugin (15 fps) | [`strata/40-apps/oled-span/`](../../strata/40-apps/oled-span/) (`install-kde.sh --apply`) |
| Desktop | No icons: the **Desktop** layout (`org.kde.desktopcontainment`), not Folder View, so `~/Desktop` stays out of sight | Right-click the desktop → Desktop and Wallpaper → Layout |
| Lock screen | The live OLED Span wallpaper, no blur behind the form | [`strata/40-apps/oled-span/kde-screens/`](../../strata/40-apps/oled-span/kde-screens/) (`--lock`; `lockscreen/` patch, sudo) |
| Login splash | OLED Span still with a thin grey spinner | same (`--splash`) |
| Login screen (SDDM) | Theme `oled-span`: Breeze with the OLED Span still and a fixed `23:49` / `2026-11-27` clock | same (`sddm/install-sddm-theme.sh`, sudo) |
| Boot splash | Plymouth `bgrt` (the laptop maker's logo). The `oled-span` theme booted the main kernel to a black screen on 2026-11-27, so it's on hold | same README |
| Shell | zsh + Starship | [`strata/20-shell/zsh/`](../../strata/20-shell/zsh/), [`strata/20-shell/starship/`](../../strata/20-shell/starship/) |

## Panels

- **Top panel (floating, rounded, bordered):** laid out like the Windows YASB bar
  ([`strata/40-apps/yasb/`](../../strata/40-apps/yasb/)), with the widgets in
  [`strata/40-apps/kde-bar/`](../../strata/40-apps/kde-bar/):
  - **Left:** the focused app's name, the global menu, the playing track
    with ⏮ ⏯ ⏭ and a visualizer (`cava`), then CPU / RAM / GPU and the weather.
  - **Centre:** date and time (`2026-11-28  00:44`, a fixed format like Windows; click for the month calendar), the
    next calendar event, and the quick-apps pill (Dolphin, WezTerm, System Monitor, System Settings).
  - **Right:** the AI usage widget ([`strata/40-apps/ai-usage/`](../../strata/40-apps/ai-usage/)),
    the system tray and a power button that opens the leave screen.
  - The two flexible spacers keep the clock near the centre.
  - No launcher on the bar, as on Windows: **Meta** opens KRunner (search apps, files and
    commands), like the Windows key opens the search-only Start menu.
  - Recreate it with `strata/40-apps/kde-bar/install-kde-bar.sh --style --layout` (back up first;
    `--dry-run` previews).
- **Bottom panel:** a floating, fit-to-content dock running the custom dock widget
  [`strata/40-apps/kde-dock/`](../../strata/40-apps/kde-dock/): hover magnification, bounce, dots,
  dividers between app groups.
- The clock's calendar shows Google Calendar events through KDE's Google connector (Akonadi
  `kdepim-runtime`) and the PIM events plugin (`kdepim-addons`); sign in from Merkuro Calendar's
  **Settings → Configure Merkuro Calendar → Accounts** (the menu is in the top panel's global menu).

## Agent tooling

- `python3` (Arch package `python`): needed by the AI usage widget ([`strata/40-apps/ai-usage/`](../../strata/40-apps/ai-usage/)) and by Claude Code's guard hook ([`strata/30-dev/ai/hooks/`](../../strata/30-dev/ai/hooks/)).
- Agent environment rules: [`ENV.md`](ENV.md), deployed to `~/.agents/ENV.md`.

## Apply

```sh
mkdir -p ~/.local/share/color-schemes
cp hosts/laptop/OLED_Monochrome.colors ~/.local/share/color-schemes/
plasma-apply-colorscheme OLED_Monochrome
plasma-apply-cursortheme Bibata-Modern-Classic
```

Then pick the Plasma style, icons, application style and fonts in System Settings.
`docs/screenshots/` shows the finished result.
