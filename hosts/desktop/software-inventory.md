# Desktop Software, Application & Toolchain Inventory

**Host**: CsPS Workstation  
**OS**: Microsoft Windows 11 Pro 64-bit (Build 26300)  
**Hardware**: AMD Ryzen 5 5600X | NVIDIA RTX 3070 | 32 GB RAM

---

## 1. Media, Communication & Custom Clients

- **Sonora** (v0.45.0):
  - Modern desktop music player replacing Spotify.
  - Multi-source synced lyrics (Apple Music, LrcLib, Musixmatch, NetEase, Spotify, YouTube Music).
  - Discord Rich Presence with Sonora badge.
  - Dark ambient theme and Last.fm scrobbling.
  - Profile preserved at [`strata/40-apps/sonora/`](../../strata/40-apps/sonora/).
- **Discord with Vencord**:
  - Lightweight client modification with **41 active plugins**.
  - Highlights: `FakeNitro`, `MusicRichPresence`, `VoiceMessages`, `BetterNotesBox`, `BlurNSFW`, `ColorSighted`, `Decor`, `DisableCallIdle`, `NoTrack`, `OnePingPerDM`, `OpenInApp`, `petpet`, `PictureInPicture`, `ReadAllNotificationsButton`, `RelationshipNotifier`, `RevealAllSpoilers`, `ReverseImageSearch`, `SecretRingToneEnabler`, `ServerInfo`, `ShowHiddenChannels`, `SilentTyping`, `USRBG`, `ValidUser`, `WhoReacted`.
  - Profile preserved at [`strata/40-apps/vencord/`](../../strata/40-apps/vencord/).
- **Element**: Matrix chat client.
- **Brave**: main browser, stripped of Rewards, Wallet, VPN, Leo and telemetry with SlimBrave Neo (see [`strata/10-os/windows/`](../../strata/10-os/windows/README.md#debloat-one-time-cleanup)).
- **LibreOffice**: office suite.

---

## 2. System Management & Maintenance Tools

Preserved at [`strata/40-apps/system-tools/`](../../strata/40-apps/system-tools/):

- **WinDirStat**: Treemap disk usage visualization (`WinDirStat.WinDirStat`).
- **Revo Uninstaller**: Deep program removal and residual registry/file trace cleaning (`RevoUninstaller.RevoUninstaller`).
- **HWiNFO64**: Real-time hardware telemetry and thermal logging (`REALiX.HWiNFO`).
- **UniGetUI**: Unified package manager graphical frontend for WinGet, Scoop, and Chocolatey.
- **Wintoys**: Windows 11 performance, telemetry, service, and privacy debloat utility.
- **LocalSend**: Encrypted cross-platform local network file sharing (`LocalSend.LocalSend`).
- **OCCT**: Power supply, GPU, VRAM, and CPU stress testing.
- **DDU**: Display Driver Uninstaller for clean graphics driver installations in Safe Mode.

---

## 3. The Multi-Agent AI Ecosystem

Preserved at [`strata/30-dev/ai/`](../../strata/30-dev/ai/):

### Google Antigravity (v2.34.0, `agy` CLI 1.5.16)
- Interactive pair-programming environment with Gemini 3.8 Flash/Pro models. Permission preset Auto, terminal sandbox on, remote control off.
- **Active Plugins**: `chrome-devtools-plugin`, `context7`, `flutter`, `firebase`, `gemini-api`, `google-cloud-developer`, `google-antigravity-sdk`, `modern-web-guidance-plugin`, `android-cli-plugin`.
- **MCP Servers**: Serena MCP, GitHub MCP, Vercel MCP, Trello MCP (Context7 and Dart MCP come from their plugins).

### Claude Code CLI
- Terminal assistant with high-effort planning and subagent dispatch.
- **Skills**: `one-skill-to-rule-them-all`, `graphify`, `humanizer`, plus the shared `anti-slop-design`, `orca-cli`, `orchestration`, `trello-use`.
- **Enabled Plugins**: `superpowers`, `frontend-design`, `commit-commands`, `claude-md-management`, `github`, `vercel`, `typescript-lsp`, `pyright-lsp`, `csharp-lsp`, `php-lsp`. `ponytail` is enabled only in school repos; `claude-mem` is disabled.
- **MCP Servers**: Horizon (all projects), Dart MCP (Flutter repo only), Roblox Studio MCP (Roblox repo only).

### OpenAI Codex CLI
- Sandboxed execution runtime with direct `zed` editor integration.
- **Plugins**: `codex-app-tools`, `browser`, `visualize`, `documents`, `pdf`, `spreadsheets`, `presentations`, `computer-use`, `code-review`.
- **MCP Servers**: `node_repl`, `github`, `vercel`, `context7`, `dart`.

---

## 4. Development Toolchains & Compilers

- **Rust**: `rustc` & `cargo` (`~/.cargo/bin`) via `rustup`.
- **Flutter & Dart**: Flutter SDK & Dart toolchain.
- **Node.js**: Node.js runtime, npm, and pnpm.
- **Python**: Python 3.15.2.
- **.NET SDK**: .NET 10 / 11 preview.
- **Java**: Microsoft OpenJDK 17.
- **C/C++ (MSVC)**: Visual Studio Community 2026 Insiders & 2022 Build Tools (SDK 10.0.26100).
- **VCS**: Git for Windows, GitHub CLI (`gh`), GitHub Desktop.
- **R**: WinGet package `RProject.R`.
- **Editors & IDEs**: Zed, VS Code Insiders, JetBrains Rider and Visual Studio Insiders, all on the OLED Monochrome theme ([`strata/40-apps/`](../../strata/40-apps/)).
- **Other dev tools**: Figma, Zeal (offline docs), VirtualBox, Roblox Studio.

---

## 5. Shell, Terminals & System Telemetry

- **WezTerm**: GPU-accelerated primary terminal emulator with modular Lua configuration (`strata/20-shell/wezterm/`).
- **Windows Terminal**: Elevated PowerShell Core 7 default, JetBrainsMono Nerd Font, OLED Monochrome scheme, 80% opacity (`strata/20-shell/windows-terminal/`).
- **Oh My Posh**: Custom diamond OS/Git prompt theme (`strata/20-shell/oh-my-posh/mytheme.omp.json`).
- **PowerShell 7 (pwsh)**: Core profile with OSC 7 current working directory propagation (`strata/20-shell/pwsh/`).
- **Fastfetch**: Fast system info utility with custom UTF-8 Totoro ASCII logo and live weather telemetry (`strata/20-shell/fastfetch/`).
- **Topgrade**: System-wide multi-ecosystem updater orchestrating Scoop, WinGet, Git repos, Cargo, npm, rustup, and PowerShell (`strata/10-os/windows/topgrade.toml`).
- **Git Base**: Global config with Git LFS filters, safe repos, and Windows atomic appending disabled (`strata/00-base/git/`).

---

## 6. Gaming & Multi-Store Libraries

- **Steam Games**:
  *NTE: Neverness to Everness*, *THE FINALS*, *Battlefield™ 6*, *Counter-Strike 2*, *Bodycam*, *Tom Clancy's Rainbow Six Siege*, *PEAK*, *Turbo Overkill*, *STRAFTAT*, *The Forest*, *Silly Linguine Cat Simulator Deluxe Online*.
- **VR & Customization**: SteamVR, Wallpaper Engine.
- **Alternative Launchers**: Heroic Games (*Fortnite*), HoYoPlay (*Genshin Impact*), Horizon Launcher + Prism Launcher (*Minecraft*), Xbox App (PC Game Pass), Ubisoft Connect, Roblox.
- **Game Dev & Utilities**: Godot Engine, scrcpy, OCCT, DDU, Logitech G HUB, Mod Organizer.

---

## 7. Desktop Shell & Look

- **Windhawk**: the dock, Start menu, Explorer and Settings styling, plus three custom mods ([`strata/40-apps/windhawk/`](../../strata/40-apps/windhawk/)).
- **YASB**: the top bar, with a native one-line menu bar ([`strata/40-apps/yasb/`](../../strata/40-apps/yasb/)).
- **Wallpaper Engine**: animated wallpapers (see [the desktop profile](README.md)).
