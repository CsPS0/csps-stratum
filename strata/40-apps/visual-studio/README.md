# Visual Studio Stratum

**OLED Monochrome** theme for Visual Studio 2026, matching the KDE "OLED Monochrome" desktop and the Zed, VS Code and Rider themes.

| File | Purpose |
|---|---|
| `vstheme.py` | Builds the theme as a `.vsix`, and decodes or self-tests Visual Studio theme `.pkgdef` files |

## What it is

Visual Studio 2026's tinted themes (Cool Slate, Juicy Plum and the rest) are small `.pkgdef` files that override 17 colour tokens on top of the Dark theme. *OLED Monochrome* is one more of those:

- **Window, title bar, tabs and panels**: black.
- **Border and active indicator**: KDE accent grey `#686B6F`.
- **Accent fills (buttons, toggles)**: light grey `#B4B6B8`, the same shade Windows uses for the system accent.
- **Editor**: syntax and Git colours are Dark's, unchanged.

The token encoding is documented in `vstheme.py`. The encoder re-creates Cool Slate, Juicy Plum and Sunny Day byte for byte:

```powershell
python .\vstheme.py selftest "C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Platform\Theme.CoolSlate.pkgdef"
```

## Install

```powershell
python .\vstheme.py build "$HOME\.config\csps-stratum\build\visual-studio\OledMonochrome.vsix"
$id = (& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -prerelease -latest -property instanceId)
& "C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\VSIXInstaller.exe" /quiet "/instanceIds:$id" "$HOME\.config\csps-stratum\build\visual-studio\OledMonochrome.vsix"
```

`/instanceIds:all` skips prerelease (Insiders) installs, hence the explicit ID. The extension installs per user. Then pick **Tools → Theme → OLED Monochrome**. Uninstall it from **Extensions → Manage Extensions**.

The manifest has no `<Prerequisites>` block on purpose: with one, this Visual Studio version rejects the package as "not a valid VSIX".
