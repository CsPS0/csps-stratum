# Mobile Software, Application & Toolchain Inventory

**Device**: Samsung Galaxy A52s 5G (`SM-A528B`, `a52sxq`)  
**OS**: Android 14 (One UI 6.1, SDK 34)  
**SoC**: Qualcomm Snapdragon 778G 5G (8 Cores, `arm64-v8a`)  
**Display**: 1080×2400 AMOLED 120Hz | Physical DPI: 450 | **Custom Override DPI: 392** (~440dp width)  

---

## 1. Custom Clients & Modded Mobile Apps

- **Aliucord** (`com.aliucord`, `com.aliucord.manager`):
  - Lightweight Discord client modification for Android.
  - Active theme: `rain.json` (Dracula Dark base with DM Sans font).
  - **19 Active Plugins**: `NitroSpoof` (FakeNitro), `BetterSilentTyping`, `CallTime`, `ReadAllButton`, `ShowHiddenChannels`, `VoiceMessages`, `FakeStickers`, `FolderOpacity`, `FullBio`, `MoreSlashCommands`, `Moyai`, `NewEmojis`, `1ClickDelete`, `AlwaysAnimate`, `RemoveZoomLimit`, `SplitMessages`, `DedicatedPluginSettings`, `Themer`, `PluginRepo`.
  - Profile preserved at [`strata/40-apps/aliucord/`](../../strata/40-apps/aliucord/).
- **YouTube ReVanced** (`app.revanced.android.youtube`):
  - Ad-free playback, sponsorblock, background audio, AMOLED dark theme.
  - Managed via `app.revanced.manager.flutter` and `app.revanced.android.gms` (MicroG).
- **Outify** (`cc.tomko.outify`):
  - Spotify playlist utility and exporter companion.

---

## 2. Termux Command-Line Environment

- **Terminal**: Termux (`com.termux`) running in `/data/data/com.termux/files/home`.
- **Configuration**: Stock Termux environment using default bash prompt without shell or theme customizations.
- **Installed Packages & Toolchains** (Full list in [`packages.txt`](packages.txt)):
  - **Languages & Compilers**: `clang`, `llvm`, `lld`, `cmake`, `make`, `build-essential`, `nodejs-lts`, `npm`, `python`, `pip`, `lua54`.
  - **Networking & Tunneling**: `cloudflared` (Cloudflare Tunnel), `openssh`, `nmap`, `net-tools`, `android-tools`.
  - **CLI Tools**: `git`, `topgrade`, `fastfetch`, `lsd`, `tree`, `zola`.

---

## 3. Mobile Code Editors & Productivity

- **Acode** (`com.foxdebug.acodefree`): Full-featured Android code editor with syntax highlighting, Git integration, and local file access.
- **GitHub Mobile** (`com.github.android`): Issue tracking, pull request review, notifications.
- **LocalSend** (`org.localsend.localsend_app`): Encrypted cross-platform file transfer pairing with desktop.
- **Bitwarden** (`com.x8bit.bitwarden`): Cross-device password vault.
- **Brave Browser** (`com.brave.browser`): Privacy-focused browser synchronized with desktop.
- **Figma Mirror** (`com.figma.mirror`): Live mobile UI previews.
- **Trello** (`com.trello`): Agile project management.

---

## 4. Mobile AI Assistant Suites

- **Claude Mobile** (`com.anthropic.claude`): Anthropic Claude assistant.
- **ChatGPT Mobile** (`com.openai.chatgpt`): OpenAI ChatGPT companion.
- **Perplexity AI** (`ai.perplexity.app.android`): Conversational search engine.
- **Google Gemini** (`com.google.android.apps.bard`): Google Gemini multimodal app.
- **Google NotebookLM** (`com.google.android.apps.labs.language.tailwind`): Project Tailwind research notebook.

---

## 5. Samsung Good Lock Customization Suite

- **LockStar** (`com.samsung.systemui.lockstar`): Custom lockscreen layout, widget placement, and clock positions.
- **ClockFace** (`com.samsung.android.app.clockface`): Custom Always-On-Display and lockscreen typography.
- **Theme Designer / Theme Park** (`com.samsung.android.themedesigner`): System-wide AMOLED color palette and icon packaging.
- **Developer Display Density**: 392 DPI (~440dp width) maximizing code and terminal line visibility.
