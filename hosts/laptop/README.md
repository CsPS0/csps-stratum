# Laptop profile (Arch Linux, KDE Plasma 6)

The laptop's look is the original **OLED Monochrome**: pure black, greys and white, which the Windows
desktop copies. Most of it is KDE settings rather than files, listed here so it can be rebuilt.

| Part | Setting | Source |
|---|---|---|
| Colour scheme | **OLED Monochrome** | [`OLED_Monochrome.colors`](OLED_Monochrome.colors) → `~/.local/share/color-schemes/` |
| Global theme base | Breeze Dark (`org.kde.breezedark.desktop`) | KDE |
| Plasma style | WhiteSur-dark-mono | [WhiteSur KDE](https://github.com/vinceliuice/WhiteSur-kde) install script |
| Application style | Kvantum | `kvantum`, `kvantum-qt5` |
| Window decoration | Breeze | KDE |
| Icons | yet-another-monochrome-icon-set | AUR `yamis-icon-theme-git` |
| Cursor | Bibata Modern Classic | AUR `bibata-cursor-theme-bin` (Windows: [`strata/10-os/windows/cursors/`](../../strata/10-os/windows/cursors/)) |
| Fonts | Inter 10 (UI, 9 toolbars, 8 smallest), JetBrainsMono Nerd Font 10 (fixed) | `inter-font`, `ttf-jetbrains-mono-nerd` |
| Wallpaper | **OLED Span**, an animated black-and-white Plasma wallpaper plugin (15 fps) | [`strata/40-apps/oled-span/`](../../strata/40-apps/oled-span/) (`install-kde.sh --apply`) |
| Shell | zsh + Starship | [`strata/20-shell/`](../../strata/20-shell/) |

## Panels

- **Top panel:** application launcher, global menu, spacer, date and time (custom date `ddd d MMM`,
  date beside the time), spacer, then the AI usage widget and the system tray. The two flexible
  spacers keep the clock in the exact centre. See the root README's laptop section and
  [`strata/40-apps/ai-usage/`](../../strata/40-apps/ai-usage/).
- **Bottom panel:** a floating, fit-to-content dock running the custom dock widget
  [`strata/40-apps/kde-dock/`](../../strata/40-apps/kde-dock/): hover magnification, bounce, dots,
  dividers between app groups.
- The clock's calendar shows Google Calendar events through KDE's Google connector (Akonadi
  `kdepim-runtime`) and the PIM events plugin (`kdepim-addons`); sign in from Merkuro Calendar's
  **Settings → Configure Merkuro Calendar → Accounts** (the menu is in the top panel's global menu).

## Apply

```sh
mkdir -p ~/.local/share/color-schemes
cp hosts/laptop/OLED_Monochrome.colors ~/.local/share/color-schemes/
plasma-apply-colorscheme OLED_Monochrome
plasma-apply-cursortheme Bibata-Modern-Classic
```

Then pick the Plasma style, icons, application style and fonts in System Settings.
`docs/screenshots/` shows the finished result.
