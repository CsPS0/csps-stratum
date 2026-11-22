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
