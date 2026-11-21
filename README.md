# csps-stratum

> Unified configuration layers, automation scripts, and application profiles orchestrated across desktop, laptop, and mobile devices.

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-blue)](#device-profiles-matrix)
[![Shells](https://img.shields.io/badge/Shells-PowerShell%20%7C%20Bash-orange)](#the-stratum-model)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#license)

`csps-stratum` solves configuration drift across heterogeneous machines. Instead of maintaining monolithic dotfiles or disparate setups per machine, **Stratum** organizes system configurations into modular, composable layers stacked cleanly according to the host platform, form factor, and development workflow.

---

## The Stratum Model

Like geological strata, your working environment is composed of hierarchical layers. Lower strata provide a universal baseline, while higher strata supply platform-specific adaptations and device-level tuning:

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST PROFILES (hosts/)                   │
│         [desktop]        │ [laptop, planned] │   [mobile]   │
├──────────────────────────┴───────────────────┴──────────────┤
│ 40-apps   │ Editors & app clients (Zed, VS Code, Vencord…)  │
│ 30-dev    │ Toolchains & AI assistants (Rust, .NET, Claude) │
│ 20-shell  │ Shell, prompt & terminals (pwsh, WezTerm, OMP)  │
│ 10-os     │ OS integration (WinGet, Scoop, Topgrade)        │
│ 00-base   │ Universal core (Git defaults)                   │
└─────────────────────────────────────────────────────────────┘
```

- **`00-base`**: Foundational conventions shared by every device (Git configuration and LFS filters).
- **`10-os`**: Operating system plumbing (WinGet and Scoop package manifests, Topgrade updater config).
- **`20-shell`**: Interactive shell experience (PowerShell 7 profile, Oh My Posh theme, WezTerm, Windows Terminal, Fastfetch).
- **`30-dev`**: Language toolchains, package managers, and the AI coding assistant configs (Antigravity, Claude Code, Codex).
- **`40-apps`**: Application-level preferences (Zed, VS Code Insiders, Windhawk, Sonora, Vencord, Aliucord, gaming and system tools).
- **`hosts/`**: Final overlay matching the exact machine role (workstation desktop or handheld device).

---

## Device Profiles Matrix

| Attribute | Desktop (`hosts/desktop`) | Laptop (planned) | Mobile (`hosts/mobile`) |
|---|---|---|---|
| **Primary OS** | Windows 11 Pro | Windows 11 | Android 14 (One UI 6.1) |
| **Form Factor** | Dual-monitor, high-performance workstation | Single screen, battery-constrained | Touchscreen, compact CLI companion |
| **Power Strategy** | Uncapped performance, GPU acceleration | Battery-aware, aggressive sleep | Minimal background wakeups |
| **Primary Shell** | PowerShell 7 + Oh My Posh | PowerShell 7 | Bash (stock Termux) |
| **Terminal** | WezTerm / Windows Terminal | Windows Terminal | Termux |
| **Toolchains** | Full development suites (Rust, Flutter, .NET, Node, Python) | Lightweight dev toolchains, remote SSH | Clang, Node, Python, OpenSSH in Termux |
| **Sync Strategy** | `bin/stratum.ps1 sync` (backup + copy) | — | Inventory only (no automated deploy) |

---

## Directory Layout

```
csps-stratum/
├── bin/                     # Entrypoints
│   ├── stratum              # POSIX shell dispatcher (Linux/macOS/Termux)
│   └── stratum.ps1          # PowerShell dispatcher (Windows)
├── strata/                  # Composable configuration layers
│   ├── 00-base/git/         # Universal Git configuration (LFS, line endings, identity template)
│   ├── 10-os/windows/       # Windows manifests (winget.json, scoop.json, topgrade.toml)
│   ├── 20-shell/            # pwsh, oh-my-posh, wezterm, windows-terminal, fastfetch
│   ├── 30-dev/              # Toolchain manifest & AI assistants (antigravity, claude, codex)
│   └── 40-apps/             # zed, vscode, windhawk, sonora, vencord, aliucord, system-tools, gaming
├── hosts/                   # Machine-specific profiles
│   ├── desktop/             # Workstation profile, setup.ps1, software-inventory.md, screenshots
│   └── mobile/              # Samsung Galaxy A52s 5G companion profile & package inventory
├── .gitattributes           # Line ending & encoding rules (LF on Unix, CRLF on PS1, UTF-16 .reg)
├── .gitignore               # Exclusion of secrets, keys, machine caches, and local agent files
├── LICENSE
└── README.md
```

A `laptop` host profile is planned but not in the repository yet.

---

## Quickstart & Bootstrapping

### Windows (PowerShell 7+)

Clone and apply the baseline strata and desktop profile:

```powershell
# 1. Clone to your preferred projects directory
git clone https://github.com/CsPS0/csps-stratum.git "$HOME\Projects\csps-stratum"
cd "$HOME\Projects\csps-stratum"

# 2. Run diagnostic health checks
.\bin\stratum.ps1 doctor

# 3. Check for configuration drift against repository
.\bin\stratum.ps1 diff

# 4. Preview changes safely (-DryRun and -WhatIf are equivalent)
.\bin\stratum.ps1 sync -Profile desktop -WhatIf

# 5. Apply the configuration
.\bin\stratum.ps1 sync -Profile desktop
```

> **Before step 5:** files in the repository are published copies with personal values removed. `strata/00-base/git/.gitconfig` contains `<YOUR_NAME>` / `<YOUR_EMAIL>` placeholders, and the Sonora and Vencord settings have their account fields blanked. Fill those in locally (without committing them) or restore them from the backup afterwards.

---

## Key Features

### 1. Non-Destructive Deployment
`setup.ps1` copies files from the active strata into your user profile (`$HOME`, `%APPDATA%`, `$PROFILE`). If a configuration file or folder already exists:
- It is never silently overwritten.
- A timestamped backup is kept first, in `~/.stratum_backups/<yyyyMMdd_HHmmss>/`.
- `-WhatIf` / `-DryRun` previews every step without touching the system.

### 2. Matched Editors
Zed and VS Code Insiders share the same theme, keymap, fonts, layout and equivalent extensions; see [`strata/40-apps/zed/`](strata/40-apps/zed/) and [`strata/40-apps/vscode/`](strata/40-apps/vscode/).

### 3. Strict Secret & Credential Hygiene
No private keys, auth tokens, or passwords are ever stored in this repository:
- All secrets are managed via external password managers or system credential stores.
- Account fields in app configs are left empty or use `<YOUR_…>` placeholders.
- Machine-local overrides are loaded from untracked `*.local.*` files (ignored by `.gitignore`).

---

## AI Agent & Automation Integration

This repository is set up for pairing with AI assistants (Claude Code, Gemini CLI, Google Antigravity, Codex). The agent instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) are kept locally and are not published. They define:

- Zero AI attribution in commits and pull requests.
- Secret safety and placeholder conventions.
- Verification gates (syntax checks and dry runs before anything is declared done).

The assistants' own configs live in [`strata/30-dev/ai/`](strata/30-dev/ai/).

---

## Contributing & Maintenance

1. **Verify Before Committing**: Run syntax and dry-run tests on any modified shell or PowerShell scripts.
2. **Follow Line Ending Standards**: Keep Unix scripts on `LF` and Windows PowerShell scripts on `CRLF`, as governed by [`.gitattributes`](.gitattributes).
3. **No AI Attribution**: Maintain clean git logs without `Co-authored-by` or AI generator trailers.

---

## License

Created by **[@CsPS0](https://github.com/CsPS0)**.  
Released under the [MIT License](LICENSE).
