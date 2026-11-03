# csps-stratum

> Unified configuration layers, automation scripts, and application profiles orchestrated across desktop, laptop, and mobile devices.

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android-blue)](#device-profiles-matrix)
[![Shells](https://img.shields.io/badge/Shells-PowerShell%20%7C%20Zsh%20%7C%20Bash%20%7C%20Nushell-orange)](#strata-layered-architecture)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#license)

`csps-stratum` solves configuration drift across heterogeneous machines. Instead of maintaining monolithic dotfiles or disparate setups per machine, **Stratum** organizes system configurations into modular, composable layers stacked cleanly according to the host platform, form factor, and development workflow.

---

## The Stratum Model

Like geological strata, your working environment is composed of hierarchical layers. Lower strata provide a universal baseline, while higher strata supply platform-specific adaptations and device-level tuning:

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST PROFILES (hosts/)                   │
│         [desktop]        │      [laptop]     │   [mobile]   │
├──────────────────────────┴───────────────────┴──────────────┤
│ 40-apps   │ Editor & Terminal configs (VS Code, Neovim, etc)│
│ 30-dev    │ Language SDKs & Toolchains (Rust, Py, Node, Go) │
│ 20-shell  │ Prompts, Aliases, Completions (Starship, Zsh)   │
│ 10-os     │ OS Integration (Windows Registry, Linux XDG)    │
│ 00-base   │ Universal Core (Git defaults, base editorconfig)│
└─────────────────────────────────────────────────────────────┘
```

- **`00-base`**: Foundational conventions shared by every single device (Git configs, core editor standards, universal aliases).
- **`10-os`**: Operating system plumbing (Windows terminal/registry, Linux desktop entries, macOS defaults, Android/Termux environment).
- **`20-shell`**: Interactive shell experiences (PowerShell 7+, Zsh, Bash, Starship cross-shell prompt, auto-suggestions, syntax highlighting).
- **`30-dev`**: Language toolchains, runtime versions, global linters, and package managers.
- **`40-apps`**: Application-level preferences (VS Code settings/keybindings, Alacritty, WezTerm, Neovim).
- **`hosts/`**: Final overlay matching the exact machine role (workstation desktop, mobile laptop, or handheld device).

---

## Device Profiles Matrix

| Attribute | Desktop (`hosts/desktop`) | Laptop (`hosts/laptop`) | Mobile (`hosts/mobile`) |
|---|---|---|---|
| **Primary OS** | Windows 11 / Linux Desktop | Windows 11 / Linux / macOS | Android (Termux) |
| **Form Factor** | Multi-monitor, high-performance workstation | Single/dual screen, battery-constrained | Touchscreen, compact CLI companion |
| **Power Strategy** | Uncapped performance, GPU acceleration | Battery-aware, aggressive sleep/hibernate | Minimal background wakeups, low memory |
| **Primary Shell** | PowerShell 7+ / Zsh | PowerShell 7+ / Zsh | Zsh / Bash (Termux) |
| **Terminal** | Windows Terminal / WezTerm | Windows Terminal / Alacritty | Termux |
| **Toolchains** | Full development suites (Docker, CUDA, Rust) | Lightweight dev toolchains, remote SSH | Remote SSH client, quick Git triage, CLI notes |
| **Sync Strategy** | Git pull + automated stratum linking | Git pull + automated stratum linking | Git pull / sparse-checkout |

---

## Directory Layout

```
csps-stratum/
├── .github/                 # GitHub workflows, issue templates, PR checklists
├── bin/                     # Bootstrap entrypoints & profile linkers
│   ├── stratum              # Master POSIX shell dispatcher (Linux/macOS/Termux)
│   └── stratum.ps1          # Master PowerShell dispatcher (Windows)
├── strata/                  # Composable configuration layers
│   ├── 00-base/git/         # Universal Git configuration (LFS, line endings, identities)
│   ├── 10-os/windows/       # Windows OS manifests (winget.json, scoop.json, topgrade.toml)
│   ├── 20-shell/            # Shell configs (wezterm, fastfetch, windows-terminal, oh-my-posh, pwsh)
│   ├── 30-dev/              # Dev toolchains & AI assistants (antigravity, claude, codex)
│   └── 40-apps/             # Apps (windhawk, zed, vscode, sonora, vencord, aliucord, system-tools, gaming)
├── hosts/                   # Machine-specific profiles
│   ├── desktop/             # Workstation profile, setup.ps1, software-inventory.md, screenshots
│   ├── laptop/              # Portable profile & battery-saving tweaks (template)
│   └── mobile/              # Samsung Galaxy A52s 5G companion profile & package inventory
├── modules/                 # Reusable utility scripts (symlink engines, package installers)
├── docs/                    # Architectural notes, onboarding guides, cheatsheets
├── .gitattributes           # Strict line ending rules (LF on Unix, CRLF on PS1)
├── .gitignore               # Strict exclusion of secrets, keys, and machine caches
├── AGENTS.md                # Shared AI coding agent instructions & conventions
├── CLAUDE.md                # Claude Code specific rules & plugin catalog
├── GEMINI.md                # Gemini CLI & Google Antigravity specific guidance
└── README.md                # Project documentation (this file)
```

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

# 4. Preview changes safely in dry-run mode
.\bin\stratum.ps1 sync -Profile desktop -WhatIf

# 5. Apply the configuration
.\bin\stratum.ps1 sync -Profile desktop
```

---

## Key Features

### 1. Non-Destructive Symlinking
Stratum safely creates symlinks from the active strata into your user profile (`$HOME`, `$XDG_CONFIG_HOME`, or `$PROFILE`). If an existing configuration file is encountered:
- It is never silently overwritten.
- An automatic timestamped backup is preserved (e.g. `~/.zshrc.bak.20261030_004500`).
- Rollback commands allow instant reversion.

### 2. Multi-Shell Harmonization
Whether you are on Windows in `pwsh`, in Linux/macOS on `zsh`, or in Termux on `bash`, your aliases, prompt layout, and Git shortcuts behave identically thanks to unified Starship prompt rules and shared alias declarations.

### 3. Strict Secret & Credential Hygiene
No private keys, auth tokens, or passwords are ever stored in this repository:
- All secrets are managed via external password managers (Bitwarden, 1Password, KeePassXC) or system credential stores.
- Environment variables utilize `.env.example` templates.
- Machine-local overrides are loaded from untracked `*.local.yaml` or `*.local.ps1` files (ignored by `.gitignore`).

---

## AI Agent & Automation Integration

This repository is built for seamless pairing with AI assistants (Claude Code, Gemini CLI, Google Antigravity, Cursor, etc.). Detailed rules are structured across dedicated instruction files:

- **[`AGENTS.md`](AGENTS.md)**: Universal rules applicable to all AI agents. Defines zero-attribution policies, secret safety, test verification gates, and fallback behavior.
- **[`CLAUDE.md`](CLAUDE.md)**: Claude Code specific directives, including the plugin catalog (`superpowers`, `serena`, `context7`, `claude-mem`).
- **[`GEMINI.md`](GEMINI.md)**: Gemini CLI & Antigravity specific directives, covering PowerShell execution on Windows, subagents, and MCP tool handling.

### MCP Tooling Highlights
- **Serena MCP**: Used for semantic code intelligence, symbol search, and precise file refactoring.
- **Context7 MCP**: Used for querying up-to-date CLI documentation, package schemas, and API references without hallucinations.

---

## Contributing & Maintenance

1. **Verify Before Committing**: Run syntax and dry-run tests on any modified shell or PowerShell scripts.
2. **Follow Line Ending Standards**: Keep Unix scripts on `LF` and Windows PowerShell scripts on `CRLF`/`LF` as governed by [`.gitattributes`](.gitattributes).
3. **No AI Attribution**: Maintain clean git logs without `Co-authored-by` or AI generator trailers.

---

## License

Created by **[@CsPS0](https://github.com/CsPS0)**.  
Released under the [MIT License](LICENSE).
