# Windhawk Stratum

This layer encapsulates configuration, active mods, and registry customizations for **Windhawk** (v1.7.3+) on Windows 11.

---

## Active Windhawk Mods Overview

The desktop profile uses Windhawk to achieve a cohesive, translucent macOS-inspired dock aesthetic while maintaining Windows 11 system efficiency.

| Mod Identifier | Version | Purpose & Visual Role |
|---|---|---|
| `windows-11-taskbar-styler` | 1.10 | Applies the **LiquidGlass2** taskbar styling, custom XAML styles, and glass blur. |
| `windows-11-start-menu-styler`| 1.7 | Pairs the Start Menu with the **LiquidGlass2** glass theme. |
| `windows-11-file-explorer-styler`| 1.7.2 | Compact navigation bar and **OS26 Liquid Glass** styling with `micaAlt` background. |
| `windows-11-notification-center-styler`| 1.8 | Harmonizes Action Center and notification popups with the translucent palette. |
| `windows-11-settings-styler`| 1.2.1 | Glass/translucent treatment for Windows 11 Settings app. |
| `taskbar-icon-size` | 1.3.11 | Custom height (60px), icon dimensions (35px), and button widths (44px) for dock proportions. |
| `hide-start-button` | 1.0 | Hides the default Windows 11 Start button for a streamlined dock look. |
| `taskbar-dock-animation` | 1.9.2 | macOS-style dock icon magnification and hover physics on taskbar items. Set to animate apps only (`ExcludeSystemButtonsMode=3`) with default spacing (`50`): on this Windows build the tray sits inside the taskbar frame (LiquidGlass2's `TrayInFrame` mode), so animating "system" elements made the tray pill grow on hover and shove the dock left. |
| `translucent-windows` | 1.8.2 | Acrylic blur behind active application surfaces (`3A232323`). |
| `icon-resource-redirect` | 1.3 | Redirects system shell DLLs to **macOS Dark Mode** icon sets (`niivu`). |
| `taskbar-tray-system-icon-tweaks` | 1.3.1 | Cleans up and spaces system tray icons. |
| `taskbar-thumbnail-reorder` | 1.1.5 | Reordering capability for taskbar preview thumbnails. |
| `taskbar-button-click` | 1.0.9 | Advanced mouse click handling on running apps (Ctrl+Click to close). |
| `explorer-details-better-file-sizes` | 1.6 | Human-friendly size formatting (MB/GB) in File Explorer details view. |
| `extension-change-no-warning` | 1.0.1 | Disables the redundant confirmation prompt when renaming file extensions. |

---

## Files in this Stratum

- `userprofile.json`: Canonical Windhawk active mods declaration.
- `mods-settings.reg`: Exported registry settings under `HKLM\SOFTWARE\Windhawk\Engine\Mods`.
