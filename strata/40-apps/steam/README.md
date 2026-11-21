# Steam Stratum

OLED Monochrome colours for Steam with [Millennium](https://steambrew.app) (Steambrew) and the *SpaceTheme for Steam* theme. They match the KDE "OLED Monochrome" desktop and the editor themes.

| File | Purpose |
|---|---|
| `theme-colors.json` | SpaceTheme's 17 colour variables, written into Millennium's `config.json` under `themes.themeColors` |
| `quick.css` | Millennium Quick CSS: greys for the few colours SpaceTheme and Steam hard-code |
| `Set-SteamThemeColors.ps1` | Writes both into `<Steam>\millennium\config\`, with timestamped `.bak` copies. Supports `-WhatIf`. |

## What it looks like

- **Backgrounds**: pure black, with panels in steps from `#080808` to `#222222`.
- **Accent, scrollbars, Download and Play buttons, focus rings**: KDE accent grey `#686B6F` and lighter greys. The original blue, green, red and yellow become greys of different brightness, so buttons still stand apart without colour.
- **Metacritic bars**: good, mixed and bad scores show as three shades of grey.
- **Logo, achievements bar, event badges and the "ready to play" icon**: grey.
- Game artwork keeps its colours.

## Apply

Steam must be closed, because Millennium writes its config back when Steam exits.

```powershell
.\Set-SteamThemeColors.ps1 -WhatIf
.\Set-SteamThemeColors.ps1
```

Only the SpaceTheme colours and Quick CSS change. Other Millennium settings, theme options and plugins are left alone. You can still adjust the colours afterwards under **Millennium → Themes → SpaceTheme → Colors**. Running the script again restores these values.

To undo, restore the newest `config.json.*.bak` and `quick.css.*.bak` in `<Steam>\millennium\config\`. Or reset the colours in Millennium's theme settings and clear Quick CSS.

The class names in `quick.css` come from Steam's and SpaceTheme's current CSS. After a big Steam or SpaceTheme update, a hard-coded colour may come back. If it does, find its new class name and update `quick.css`.
