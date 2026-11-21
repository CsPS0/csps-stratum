# Windows OS Stratum (`10-os/windows`)

Package manager manifests and system-wide maintenance automation for Windows 11.

## Manifests & Tools
- `winget.json`: Declarative Microsoft WinGet package definitions.
- `scoop.json`: Declarative Scoop apps, buckets (`main`), and configurations.
- `topgrade.toml`: Cross-ecosystem package upgrade orchestrator (updates Scoop, WinGet, Git repos, Cargo, npm, rustup, PowerShell modules in a single step).

## Monochrome look (matches the KDE "OLED Monochrome" laptop)
- `monochrome-colors/Set-MonochromeColors.ps1`: system-wide colours, per user, no elevation.
  - Accent: neutral grey palette around `#686B6F`. Modern apps (Settings, Start, Quick Settings, WinUI toggles and buttons) use it.
  - Classic colours: selection highlight `#686B6F` with white text, menu highlight, and link colour `#C8C8C8`. Win32 and Qt apps use these.
  - Pointer: plain white Windows Default scheme.
  - Saves the previous values to `~/.config/csps-stratum/backups/colors-*.json` first. `-Restore <file>` undoes it, and `-WhatIf` previews it.
- `dock-icons/`: monochrome icons for the dock, Start menu and the apps' own windows (see its README).
- Taskbar, Start, notification centre, Explorer and window tint: Windhawk stylers in `strata/40-apps/windhawk/`.
- Terminals and prompt: `strata/20-shell/` (WezTerm, Windows Terminal, Oh My Posh).

Some apps theme themselves and ignore all of the above (Brave, Discord, Zed, VS Code). Their own theme settings decide their colours.
