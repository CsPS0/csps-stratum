# Cursors

Both machines use **Bibata Modern Classic**, a black, rounded, monochrome cursor set
([ful1e5/Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor), GPL-3.0). The cursor files
aren't committed; the release zip is downloaded and installed per user.

| Machine | How |
|---|---|
| Windows | `Install-BibataCursors.ps1` copies the regular-size cursors into `%LOCALAPPDATA%\Cursors\Bibata-Modern-Classic` (no admin; the release's own `install.inf` writes to `C:\Windows\Cursors`). [`Set-MonochromeColors.ps1`](../monochrome-colors/Set-MonochromeColors.ps1) then sets them as the pointer scheme, and falls back to Windows' white Aero cursors when they aren't installed. |
| Laptop (KDE) | Already set: `cursorTheme=Bibata-Modern-Classic` in `~/.config/kcminputrc`, from Arch's Bibata package. |

```powershell
gh release download v2.0.7 -R ful1e5/Bibata_Cursor -p Bibata-Modern-Classic-Windows.zip -D $env:TEMP\bibata
.\Install-BibataCursors.ps1 -Zip $env:TEMP\bibata\Bibata-Modern-Classic-Windows.zip   # -Size Large for bigger cursors
..\monochrome-colors\Set-MonochromeColors.ps1
```

`Set-MonochromeColors.ps1` saves the previous values first; `-Restore <backup>` puts them back.

**Run these in a normal terminal** (Windows Terminal or WezTerm started from Start or the dock), not
from a terminal inside an MSIX-packaged app such as the Claude desktop app. A packaged app's shells
get a private copy of `%LOCALAPPDATA%` and of the user registry (`HKCU`). The cursors then land in
`%LOCALAPPDATA%\Packages\<app>\LocalCache\Local\Cursors` and the scheme in the app's own registry
copy. Inside the app everything looks installed, but Windows keeps the default pointer. That
happened here on 2026-11-22 and was noticed on 2026-11-28.
