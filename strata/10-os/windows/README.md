# Windows OS Stratum (`10-os/windows`)

Package manager manifests and system-wide maintenance automation for Windows 11.

## Manifests & Tools
- `winget.json`: Declarative Microsoft WinGet package definitions.
- `scoop.json`: Declarative Scoop apps, buckets (`main`), and configurations.
- `topgrade.toml`: Cross-ecosystem package upgrade orchestrator (updates Scoop, WinGet, Git repos, Cargo, npm, rustup, PowerShell modules in a single step).

## Debloat (one-time cleanup)

These two tools removed the junk from this Windows install. They're third-party and aren't vendored
in the repo; run them from their own projects.

| Tool | What it cleaned | Source |
|---|---|---|
| **Win11Debloat** | Preinstalled apps; telemetry, activity history and app-launch tracking; ads, tips and suggestions (Windows, lock screen, Start, Settings, Edge); Copilot, Recall and Click to Do; Bing web search in Start; plus optional system, update, Start and taskbar tweaks. | [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat) (MIT) |
| **SlimBrave Neo** | Brave's own extras (metrics, P3A analytics, stats ping, variations/experiments, Rewards, Wallet, VPN, Leo AI and more), set as Chromium enterprise policies so Brave can't turn them back on; presets or one by one. | [ChaoticSi1ence/SlimBrave-Neo](https://github.com/ChaoticSi1ence/SlimBrave-Neo) (GPL-3.0) |

Both need an elevated PowerShell and change settings for the whole machine, so read their
on-screen choices before applying. Prefer a downloaded release over piping a script from the web:

```powershell
# Win11Debloat: download the latest release zip from its GitHub page and extract it, then (admin):
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Win11Debloat.ps1

# SlimBrave Neo (admin; Brave closed). Its SECURITY.md lists tagged releases with SHA-256 sums.
git clone https://github.com/ChaoticSi1ence/SlimBrave-Neo.git
cd SlimBrave-Neo
powershell -ExecutionPolicy Bypass -File .\SlimBrave.ps1
```

Run them again after a major Windows feature update (it can bring apps and suggestions back) or a
Brave reinstall. SlimBrave Neo also runs on Linux: the laptop's Brave gets the same policies from a
config converted from this machine's (45 policies, plus automatic secure DNS; the rest are
Chrome/ChromeOS-only keys its Linux version doesn't list), applied with
`sudo python3 slimbrave-linux.py --import <config.json>`, which writes
`/etc/brave/policies/managed/slimbrave.json`.

## Monochrome look (matches the KDE "OLED Monochrome" laptop)
- `monochrome-colors/Set-MonochromeColors.ps1`: system-wide colours, per user, no elevation.
  - Accent: neutral grey palette around `#686B6F`. Modern apps (Settings, Start, Quick Settings, WinUI toggles and buttons) use it.
  - Classic colours: selection highlight `#686B6F` with white text, menu highlight, and link colour `#C8C8C8`. Win32 and Qt apps use these.
  - Pointer: Bibata Modern Classic (black, as on the laptop) once `cursors/Install-BibataCursors.ps1` has installed it; otherwise the plain white Windows Default scheme.
  - Saves the previous values to `~/.config/csps-stratum/backups/colors-*.json` first. `-Restore <file>` undoes it, and `-WhatIf` previews it.
- `dock-icons/`: monochrome icons for the dock, Start menu and the apps' own windows (see its README).
- Taskbar, Start, notification centre, Explorer and window tint: Windhawk stylers in `strata/40-apps/windhawk/`.
- Terminals and prompt: `strata/20-shell/` (WezTerm, Windows Terminal, Oh My Posh).

Some apps theme themselves and ignore all of the above (Brave, Discord, Zed, VS Code). Their own theme settings decide their colours.
