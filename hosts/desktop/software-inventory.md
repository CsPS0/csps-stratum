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

### Google Antigravity (v2.28.2)
- Interactive pair-programming environment with Gemini 3.8 Flash/Pro models.
- **Active Plugins**: `chrome-devtools-plugin`, `data-agent-kit-plugin`, `flutter`, `google-cloud-developer`, `science`, `firebase`, `gemini-api`, `gdocs`, `gsheets`, `gslides`, `gdrive`, `gcalendar`, `android-cli-plugin`.
- **MCP Servers**: Serena MCP, Context7 MCP, GitHub MCP, Playwright MCP, Vercel MCP, Trello MCP.

### Claude Code CLI
- Terminal assistant with high-effort planning and subagent dispatch.
- **Skills**: `one-skill-to-rule-them-all`, `graphify`, `humanizer`.
- **Enabled Plugins**: `superpowers`, `claude-mem`, `ponytail`, `frontend-design`, `commit-commands`, `claude-md-management`, `github`, `vercel`, `typescript-lsp`, `pyright-lsp`, `csharp-lsp`, `php-lsp`.

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

---

## 5. Shell, Terminals & System Telemetry

- **WezTerm**: GPU-accelerated primary terminal emulator with modular Lua configuration (`strata/20-shell/wezterm/`).
- **Windows Terminal**: Elevated PowerShell Core 7 default, JetBrainsMono Nerd Font, 80% opacity with acrylic blur (`strata/20-shell/windows-terminal/`).
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
- **Game Dev & Utilities**: Godot Engine, scrcpy, OCCT, DDU, Logitech G HUB.
