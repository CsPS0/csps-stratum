# Lazy install with an AI agent

This repository holds a black-and-white **OLED Monochrome** setup for a Windows 11 desktop and an
Arch Linux (KDE Plasma 6) laptop: macOS-style top bars and docks, matching editor and terminal
themes, monochrome icons and cursors. See [`docs/screenshots/`](docs/screenshots/) for the result.

You don't have to read all of it. Clone it, open a coding agent in the folder, and paste the prompt
below. The agent looks at your machine, asks what you want to keep, change or skip, writes a plan for
you to approve, and only then builds it.

## How to use it

1. Clone the repository and open a terminal in it:
   ```sh
   git clone https://github.com/CsPS0/csps-stratum.git
   cd csps-stratum
   ```
2. Start a coding agent that can read files and run commands there (for example Claude Code,
   Gemini CLI or Codex) and switch it to **plan mode** (read-only), if it has one.
3. Paste the whole prompt below.
4. Answer its questions, read its plan, and approve it. Then let it work in auto mode (or approve
   each step, if you prefer). It will stop and ask you whenever something needs an administrator
   password, a sign-in, or a click it can't make.

Make a system restore point (Windows) or a snapshot/backup (Linux) first. Everything below is
reversible, but some of it changes system-wide settings.

## The prompt

````text
You are setting up my computer to look and work like the "csps-stratum" setup in this repository
(the current folder): a black-and-white "OLED Monochrome" desktop with macOS-style top bar and dock,
matching editor/terminal themes, monochrome icons and cursors. Adapt it to MY machine and MY choices.
The repository's README files are your source of truth for what each part does and how it's applied.

## How you work

1. Plan first. Do not change anything until I have approved a written plan. If you have a plan mode,
   stay in it until then. After approval, work through the plan phase by phase.
2. Ask, don't assume. Interview me (step 3 below) before planning. Ask one topic at a time, offer the
   repo's choice as the default, and say plainly when something won't work on my system and what the
   closest alternative is.
3. Be safe and reversible:
   - Back up every file, registry key and setting before you change it, and tell me where the backup is.
   - Use the scripts' dry-run modes first (-WhatIf on PowerShell, --dry-run on shell scripts) and show me
     what they would do.
   - Never overwrite my existing configs without a backup; merge instead of replacing where you can.
   - Download only from the official sources the READMEs link to (GitHub releases, package managers);
     tell me the file, source and size before downloading, and never run a script piped from the web
     when a release download exists.
4. Privacy and secrets: never copy anyone's personal data from this repo into my setup, and never write
   my secrets into files. The repo's exports contain the original author's paths and app IDs (for
   example C:/Users/<name>/... icon paths in strata/40-apps/windhawk/mods-settings.reg); replace them
   with mine. Calendar links, tokens, account names and similar go only where the READMEs say (local,
   git-ignored files), and only if I give them to you.
5. Things you can't do yourself (administrator/UAC prompts, sudo passwords, signing in to accounts,
   pasting a mod into Windhawk's editor, clicking in a GUI): stop, tell me exactly what to do, then
   check the result yourself afterwards.
6. Verify each phase before moving on: run the scripts' checks, re-read configs, take screenshots of
   the result if you can, and compare with docs/screenshots/. Report honestly what worked and what
   didn't.
7. Don't commit or push anything to any git repository unless I ask.

## Step 1: Discover my system (read-only)

Find out and summarise:
- OS, edition, version and build (Windows: winver/build number, e.g. 11 24H2 26100; Linux: distro and
  version, kernel, desktop environment and its version (KDE Plasma 5 or 6, GNOME, ...), Wayland/X11;
  macOS version).
- CPU architecture (x64 or ARM64), monitors (count, resolutions, scaling), GPU.
- Package managers available (winget, scoop, choco / pacman + AUR helper, apt, dnf, zypper, flatpak /
  Homebrew), PowerShell 7 or not, Python, git.
- What is already installed from this setup's app list (editors, terminals, browsers, launchers), and
  which apps I actually use (pinned apps, recent/most-used apps), so the dock reflects MY apps.
- Existing customisations that could conflict (other taskbar mods, ExplorerPatcher/StartAllBack,
  other docks/bars, custom themes).

## Step 2: Read the repository

Read README.md, the hosts/ profiles (desktop = Windows 11, laptop = Arch KDE, mobile = Android/Termux)
and the README in every strata/ folder you'd use. Note each part's platform requirements. The map:

- strata/00-base: git config (has <YOUR_NAME>/<YOUR_EMAIL> placeholders).
- strata/10-os/windows: winget/scoop package lists, topgrade; monochrome system colours
  (monochrome-colors/Set-MonochromeColors.ps1), monochrome dock and app icons (dock-icons/),
  Bibata cursors (cursors/), debloat tools (Win11Debloat, SlimBrave Neo; third-party, optional).
- strata/20-shell: PowerShell profile, Oh My Posh, WezTerm, Windows Terminal, fastfetch.
- strata/30-dev: toolchains, AI coding assistant configs.
- strata/40-apps:
  - windhawk: taskbar dock look (oled-dock.reg, no theme; rules for the pill, dots, collapsed tray,
    transparent hover), a search-only Start menu (oled-start.reg), Explorer/Settings stylers, dock animation, separators, and three custom
    mods in custom-mods/ (pin layout, attention bounce, trailing separator).
  - yasb: macOS-style top bar for Windows with a native C++ menu bar (menubar/), next-calendar-event
    widget (calendar/), Claude/Antigravity usage widgets (with ai-usage/).
  - ai-usage: the usage script, YASB popup, and a KDE Plasma 6 panel widget.
  - kde-dock: the KDE Plasma 6 dock widget (magnification, bounce, dots, group dividers).
  - oled-span: the animated black-and-white wallpaper, as Wallpaper Engine scenes (desktop span and
    phone), a web build, and a KDE Plasma 6 wallpaper plugin.
  - zed, vscode, rider, visual-studio: OLED Monochrome editor themes.
  - steam (Millennium theme colours), sonora, vencord/aliucord, gaming, minecraft, system-tools.
- hosts/laptop: the KDE look (colour scheme file, Plasma style, icons, fonts, panels).
- bin/stratum and bin/stratum.ps1: the sync tool (doctor / diff / sync -Profile <name> -WhatIf).

## Step 3: Interview me

Go through these, one area at a time, with what this repo does as the default:
1. Which machines/OSes to set up, and whether to copy the desktop profile, the laptop profile, or mix.
2. Look: full OLED Monochrome (pure black + greys), or keep some colour (accent, icons, wallpaper).
   Fonts (Inter + JetBrainsMono Nerd Font), cursor (Bibata Modern Classic), icon style.
3. Top bar: wanted or not; which widgets (clock, calendar event, AI usage, tray, volume, ...).
   The calendar widget needs MY private iCal link in a local file; ask if I want it.
4. Dock: macOS-style dock or keep my taskbar; magnification; bounce on attention; groups and
   separators; which apps to pin and in what groups (suggest groups from MY installed/used apps).
5. Editors/terminals I use (only theme the ones I have), shells, prompt.
6. Apps from the lists (browser, chat, games, tools): install, skip or replace.
7. Debloat (Windows: Win11Debloat; Brave: SlimBrave Neo): yes/no, and which options.
8. Anything I want to keep exactly as it is.

## Step 4: Capability check

Tell me what works on my system and what doesn't, using this matrix, and offer alternatives:
- Windows 11 24H2/25H2, x64: everything. Windhawk mods find taskbar code through Microsoft's symbols;
  right after a Windows update they can misbehave for a few days.
- Windows 11 23H2 and older 11 builds: the Windhawk taskbar/Explorer stylers and taskbar mods may
  partly work; test one at a time. Insider builds: some taskbar mods don't work.
- Windows 10: no Windows 11 taskbar, so none of the taskbar styling/dock mods, separators or custom
  taskbar mods apply. YASB (top bar), the colour script, icons, cursors, editor/terminal themes,
  PowerShell profile and app lists do work. Offer YASB plus a separate dock app as the alternative,
  and say what that loses.
- ARM64 Windows: the three custom mods in strata/40-apps/windhawk/custom-mods declare x86-64 only,
  so they won't load (porting means adding ARM64 to their @architecture line and testing); catalog
  mods depend on their own ARM64 support. YASB and the scripts work.
- KDE Plasma 6 (any distro): colour scheme, icons, cursor, fonts, Kvantum, the kde-dock and ai-usage
  widgets. Only package names differ from Arch (find the equivalents or install from upstream).
- KDE Plasma 5: the QML widgets target Plasma 6 APIs and won't load as-is; colour scheme, icons,
  cursor and fonts still work. Say so and offer to port or skip.
- GNOME and other desktops: no Plasma widgets. Colours/icons/cursor/fonts mostly carry over (GTK
  equivalents); for the dock and top bar suggest native extensions (e.g. a dock extension) and say
  it won't be identical.
- macOS: the editor and terminal themes and the shell prompt carry over; the top bar, dock, icon and
  cursor parts don't (macOS has its own dock and menu bar).
- Mobile (Android/Termux): hosts/mobile profile only.

## Step 5: Plan

Write a numbered plan grouped into phases (for example: 0 backups/restore point, 1 packages and
fonts, 2 colours/cursor/icons, 3 shell and terminals, 4 editors, 5 top bar, 6 dock, 7 apps and
debloat, 8 verification). For each step: what changes, which repo file or script it uses, how it's
undone, whether it needs me (admin, sign-in, GUI), and how you'll check it. Wait for my approval.

## Step 6: Build (after approval)

Work through the plan phase by phase, verifying each one. Known pitfalls from building the original
(read the READMEs for the details):
- Windows only lets Explorer itself pin or reorder taskbar apps; scripts can't. That's why the pin
  layout is a Windhawk mod. Windows renames pinned shortcuts ("Brave (10).lnk"); match pins by the
  program they start.
- Windhawk keeps a mod's saved settings across updates, so a changed default only takes effect under a
  new setting name. Custom/local mods are installed by pasting them into Windhawk's "Create a new mod"
  editor and compiling (I do that part).
- The LiquidGlass2 taskbar theme caps the dock's width; this setup uses no theme plus its own rules
  (oled-dock.reg) so the dock can hold many apps at full size.
- Each taskbar button clips its own icon, so a bounce must move the whole button, and the taskbar
  needs headroom above the dock (taller taskbar, pill at the bottom).
- Restarting Explorer can stop YASB and the menu bar; check they're still running afterwards.
- YASB's custom widgets only hide when they output plain text (empty output), not JSON.
- KDE: edit plasma-org.kde.plasma.desktop-appletsrc only while plasmashell is stopped, because it
  rewrites the file on exit; panel widgets that should fill the panel need Plasmoid.CanFillArea.
- Only add apps to the dock that I actually use.

## Step 7: Report

Finish with: what's done and verified (with screenshots if you can), what I still need to do by hand,
what was skipped and why, and where every backup is.
````
