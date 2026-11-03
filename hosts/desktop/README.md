# Desktop Profile (`hosts/desktop`)

This profile standardizes the workstation environment for **Windows 11 Pro**, tailored for multi-display development, GPU acceleration, and a customized glass-dock desktop aesthetic.

---

## Hardware & Environment Overview

- **CPU**: AMD Ryzen 5 5600X (6 Cores / 12 Threads)
- **GPU**: NVIDIA GeForce RTX 3070
- **RAM**: 32 GB DDR4
- **Operating System**: Windows 11 Pro 64-bit (Build 26300)
- **Display Matrix**:
  - **Primary Screen (Display 2)**: 1920×1080 @ (X: 0, Y: 0) with centered dock taskbar
  - **Secondary Screen (Display 1)**: 1920×1200 @ (X: 1920, Y: 0) auxiliary canvas

---

## Desktop Aesthetics & Visuals

Active wallpaper styling:

### Wallpaper Engine Active Background
![Wallpaper Engine Active Theme](assets/screenshots/wallpaper-engine-preview.jpg)
*(Theme: "Mac Book Pro M1 N&B Dark", Workshop ID: 2818923055)*

---

## Desktop Customization Architecture

| Component | Software / Engine | Configuration & Source |
|---|---|---|
| **Dock / Shell** | [Windhawk](https://windhawk.net/) (v1.7.3) | [`strata/40-apps/windhawk/`](../../strata/40-apps/windhawk/) |
| **Dock Theme** | LiquidGlass2 + macOS Dark Icons | `windows-11-taskbar-styler`, `icon-resource-redirect` |
| **Wallpaper** | Wallpaper Engine (`wallpaper64`) | Dynamic background rendering (Asset `2818923055`) |
| **Terminal (Primary)** | [WezTerm](https://wezfurlong.org/wezterm/) | [`strata/20-shell/wezterm/`](../../strata/20-shell/wezterm/) |
| **Terminal (Secondary)** | Windows Terminal | [`strata/20-shell/windows-terminal/`](../../strata/20-shell/windows-terminal/) |
| **Shell & Prompt**| PowerShell 7+ with Oh My Posh | [`strata/20-shell/pwsh/`](../../strata/20-shell/pwsh/), [`strata/20-shell/oh-my-posh/`](../../strata/20-shell/oh-my-posh/) |
| **System Info Banner** | Fastfetch (Totoro ASCII) | [`strata/20-shell/fastfetch/`](../../strata/20-shell/fastfetch/) |
| **Multi-Updater** | Topgrade | [`strata/10-os/windows/`](../../strata/10-os/windows/topgrade.toml) |
| **Base VCS** | Git LFS + Atomic disable | [`strata/00-base/git/`](../../strata/00-base/git/) |
