# JetBrains Rider Stratum

**OLED Monochrome** theme for Rider 2026.2, matching the KDE "OLED Monochrome" desktop and the Zed, VS Code and Visual Studio themes.

| File | Purpose |
|---|---|
| `plugin.xml` | Plugin descriptor: registers the UI theme and the editor colour scheme |
| `Build-RiderTheme.ps1` | Builds the theme plugin jar from the installed Rider's own theme files. `-Install` copies it into Rider's plugins folder. Supports `-WhatIf`. |

## What it looks like

- **Interface**: Rider's Islands Dark theme with every colour turned into the grey of the same brightness, on pure black, with `#E6E6E6` text and a grey accent. VCS, diff and file-status colours stay.
- **Editor**: the *Rider Islands Dark* colour scheme with its backgrounds turned black, a `#333333` selection and a `#0D0D0D` caret row. Syntax and VCS colours are unchanged.

The JetBrains theme files aren't stored in the repo. The script reads them from the Rider install each time (`lib\intellij.platform.ide.impl.jar` and `plugins\rider-theme-pack\lib\rider-theme-pack.jar`), so rebuild after a Rider update. The jar is written to `~/.config/csps-stratum/build/rider/` and isn't committed.

## Install

```powershell
.\Build-RiderTheme.ps1 -WhatIf
.\Build-RiderTheme.ps1 -Install      # Rider must be closed
```

Or build without `-Install` and use **Settings → Plugins → ⚙ → Install Plugin from Disk…** with `~/.config/csps-stratum/build/rider/oled-monochrome.jar`.

Then choose **Settings → Appearance & Behavior → Appearance → Theme → OLED Monochrome**. The editor scheme switches with it.

To undo, pick *Islands Dark* again and remove the plugin in **Settings → Plugins → Installed**.
