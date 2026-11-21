# Visual Studio Code Stratum

Configuration profile for **Visual Studio Code Insiders**.

---

## Files

| File | Deploys to (Windows) | Purpose |
|---|---|---|
| `settings.json` | `%APPDATA%\Code - Insiders\User\settings.json` | Default-profile settings (menu bar, new-window profile) |
| `profile-settings.json` | `%APPDATA%\Code - Insiders\User\profiles\<id>\settings.json` | Settings of the `CsPS` profile, where day-to-day work happens |
| `extensions.txt` | — | Extensions installed in the `CsPS` profile |
| `oled-monochrome/` | installed as the `csps.oled-monochrome` extension | The *OLED Monochrome* colour theme the profile uses |

`OLED Monochrome` is `One Dark Pro Night Flat` with its interface turned into greys of the same brightness, on a black background with `#E6E6E6` text, made with `bin/greyscale-theme.py`. Syntax colours, git colours (gutter, overview ruler, minimap, diff editor, source control graph, file-name decorations) and bracket pair colours stay as in One Dark Pro. Errors, warnings and the integrated terminal are grey. File-name git colours stay off because the profile sets `git.decorations.enabled: false`. The theme isn't on the Marketplace, so pack and install it locally:

```powershell
# only to regenerate the theme
$keep = 'tokenColors', 'semanticTokenColors', 'colors/gitDecoration.*', 'colors/editorGutter.added*', 'colors/editorGutter.modified*', 'colors/editorGutter.deleted*',
        'colors/editorOverviewRuler.added*', 'colors/editorOverviewRuler.modified*', 'colors/editorOverviewRuler.deleted*', 'colors/minimapGutter.*',
        'colors/diffEditor.*', 'colors/scmGraph.*', 'colors/inlineChatDiff.*', 'colors/editorBracketHighlight.*' | ForEach-Object { '--keep', $_ }
python .\bin\greyscale-theme.py "$HOME\.vscode-insiders\extensions\zhuangtongfa.material-theme-<version>\themes\OneDark-Pro-night-flat.json" .\strata\40-apps\vscode\oled-monochrome\themes\oled-monochrome-color-theme.json --name "OLED Monochrome" --base "#16191d" --fg "#abb2bf" @keep

python .\strata\40-apps\vscode\oled-monochrome\pack-vsix.py "$env:TEMP\oled-monochrome.vsix"
code-insiders --profile CsPS --install-extension "$env:TEMP\oled-monochrome.vsix"
```

The `CsPS` profile folder name is a random ID that differs per machine, so `profile-settings.json` is not deployed automatically. With the `CsPS` profile active, run **Preferences: Open User Settings (JSON)** and paste the file in.

Install the extensions with:

```powershell
Get-Content .\strata\40-apps\vscode\extensions.txt | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object { code-insiders --profile CsPS --install-extension $_ }
```

## Configuration Summary

- **Profile**: `CsPS` (opened for every new window)
- **Theme / Icons**: OLED Monochrome (grey interface, One Dark Pro syntax and git colours), Material Icon Theme at saturation 0 (grey)
- **Layout**: side bar on the right, activity bar on top, classic menu bar, no command center
- **Editor**: solid cursor with smooth caret animation, word wrap, linked editing, autosave after delay
- **AI**: Copilot and chat AI features disabled
- **Remote SSH**: host-to-platform map left empty in the repo (fill in locally)
- **Zed parity**: [`../zed/`](../zed/) mirrors this profile's look and extensions
