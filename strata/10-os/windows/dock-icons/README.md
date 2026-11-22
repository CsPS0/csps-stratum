# Dock icons (monochrome)

Gives pinned taskbar apps white monochrome icons that match the KDE laptop's
`yet-another-monochrome-icon-set` (GPL-3). The dock and Start menu part only changes shortcut
icon paths; no mod or background process is involved, so there's no RAM cost. The in-app part
(below) uses the icon redirect mod that is already running.

| File | Purpose |
|---|---|
| `icons.map` | Pinned shortcut name → icon name. `logo-*` names are monochrome versions of the app's own logo. |
| `build-icons.sh` | Run on a Linux host with the set installed (needs `rsvg-convert` and `magick`). Writes a 16–256 px `.ico` per app. |
| `Set-DockIcons.ps1` | Backs up the pinned `.lnk` files, then points them at the `.ico` files. `-IncludeStartMenu` also does matching Start menu shortcuts. Supports `-WhatIf` and `-Restore <backup>`. |
| `exe-icons.map` | Program file (or loose `.ico` an app loads) → icon name, for the in-app icon theme below. |
| `Build-ExeIconTheme.ps1` | Builds that theme and, with `-Register` (elevated), adds it to the icon redirect mod. Supports `-WhatIf`. |

The generated `.ico` files are not committed (GPL-3 artwork); rebuild them from the laptop:

```bash
R=$(ssh laptop mktemp -d)
scp build-icons.sh icons.map "laptop:$R/"
ssh laptop "cd $R && bash build-icons.sh icons.map out >&2 && tar -C out -cf - ." | tar -C ~/.config/csps-stratum/icons/dock -xf -
ssh laptop "rm -rf $R"
```

```powershell
.\Set-DockIcons.ps1 -WhatIf
.\Set-DockIcons.ps1
Stop-Process -Name explorer   # the taskbar caches pinned icons until Explorer restarts
```

### `logo-*` icons

Where the set has no real match (Sonora, VirtualBox, UniGetUI, Revo Uninstaller, WinDirStat), the
icon is a monochrome version of the app's own 256 px icon. Extract it on Windows (e.g.
`user32!PrivateExtractIcons` at 256×256, saved as PNG), then convert with ImageMagick:

```bash
magick vbox.png    -alpha extract -background white -alpha shape                     m.png  # flat white logo
magick sonora.png  -colorspace gray -channel RGB -negate +channel                     m.png  # invert, keep alpha
magick revo.png    -colorspace gray -level 0%,65%                                     m.png  # brightened greyscale
magick m.png -define icon:auto-resize=256,128,96,64,48,40,32,24,20,16 logo-<app>.ico
```

Icon files are named after the icon (`logo-sonora.ico`), not the app. Windows caches icons by
path, so a changed icon needs a new file name; overwriting the old file keeps showing the old image.

### File Explorer and Claude

These buttons aren't pinned `.lnk` files (File Explorer is a built-in shell pin; Claude, Windows
Terminal and Wintoys are packaged apps), so their icons come from `windows-11-taskbar-styler`
rules that swap the button image by app ID (stored in `strata/40-apps/windhawk/mods-settings.reg`):

```
Taskbar.TaskListButton[AutomationProperties.AutomationId=Appid: Microsoft.Windows.Explorer] > * > Image#Icon
    Source:=<BitmapImage UriSource="file:///C:/Users/<you>/.config/csps-stratum/icons/dock/logo-explorer.png"/>
Taskbar.TaskListButton[AutomationProperties.AutomationId=Appid: Claude_pzs8sxrjxfjjc!Claude] > * > Image#Icon
    Source:=<BitmapImage UriSource="file:///C:/Users/<you>/.config/csps-stratum/icons/dock/claude.png"/>
Taskbar.TaskListButton[AutomationProperties.AutomationId=Appid: Microsoft.WindowsTerminal_8wekyb3d8bbwe!App] > * > Image#Icon
    Source:=<BitmapImage UriSource="file:///C:/Users/<you>/.config/csps-stratum/icons/dock/logo-terminal.png"/>
Taskbar.TaskListButton[AutomationProperties.AutomationId=Appid: 11413PtruceanBogdan.Wintoys_ankwhmsh70gj6!Wintoys] > * > Image#Icon
    Source:=<BitmapImage UriSource="file:///C:/Users/<you>/.config/csps-stratum/icons/dock/logo-wintoys.png"/>
```

`claude.png` is a 256 px render of `claude.svg` from the same icon set. The `logo-*.png` files are
the apps' own icons in brightened greyscale (File Explorer uses Windows' own folder icon from
`explorer.exe`; Terminal and Wintoys use their package's 256 px logo). The same rule works for any
other running app: find its ID with `Get-StartApps`.

### Making the logo-* icons on Windows

For apps added later, the 256 px icon can be extracted with `user32!PrivateExtractIcons` and
converted with Python/Pillow instead of ImageMagick: greyscale, then brighten (`v / 0.65`, capped at
255) and keep the alpha channel. Save both `logo-<app>.ico` (16-256 px, for pinned shortcuts) and
`logo-<app>.png` (256 px, for styler rules). Don't invert dark tiles (Figma, Mod Organizer): they
stay dark grey like the original.

### Icons inside apps (title bars, Alt+Tab, Task Manager, Explorer)

Those come from the icon built into each program file, not from shortcuts. `Build-ExeIconTheme.ps1`
makes a small resource-only DLL per program that holds the monochrome icon under the program's own
main icon ID, plus a `theme.ini` mapping each program to its DLL, in
`~/.config/csps-stratum/icons/exe-theme`. Windhawk's `icon-resource-redirect` mod (Theme paths
setting) then serves icons from the DLL; anything the DLL lacks still comes from the program.
Needs `rc.exe` (Windows SDK) and `link.exe` (MSVC build tools).

```powershell
.\Build-ExeIconTheme.ps1 -WhatIf
.\Build-ExeIconTheme.ps1 -Register   # elevated; backs up the mod's settings first
```

Apps pick the icon up when they next start. Rebuild after an app update that moves its files.
What it reaches depends on how each app loads its window icon:

| Window icon changes | Window icon stays | Why |
|---|---|---|
| WezTerm, Zed, LocalSend, Sonora, VS Code Insiders, GitHub Desktop, Heroic | Prism Launcher, VirtualBox | Qt apps take the window icon from their own bundled images |
| | Antigravity | probably sets its icon from a bundled image, not an icon resource |
| | Brave | the lion comes from `chrome.dll`, but redirecting that didn't help; likely read in a way only the mod's experimental "redirect all resources" option catches |
| | UniGetUI | WinUI window; redirecting its `Assets\Images\icon.ico` didn't take |
| | WinDirStat | runs as administrator; cause not tracked down |

Discord and Element set their window icon from a loose `.ico`, which is redirected too but not yet
tested; Steam, Revo Uninstaller and Horizon Launcher weren't tested either. For every program,
icon extraction through the mod (what Task Manager and Explorer use) returns the monochrome icon;
Explorer may keep showing cached icons until its icon cache is cleared.

RAM: no new process. The already-running icon mod loads a ~420 KB data-only DLL only in a
process that asks for that program's icon.

Icons and backups live in `~/.config/csps-stratum`, **not** `AppData`. Files a packaged
(MSIX) app creates under `AppData` are redirected into that app's private package store,
where Explorer can't see them, and the dock then shows blank icons.
