# Visual Studio Code Stratum

Configuration profile for **Visual Studio Code Insiders**.

---

## Files

| File | Deploys to (Windows) | Purpose |
|---|---|---|
| `settings.json` | `%APPDATA%\Code - Insiders\User\settings.json` | Default-profile settings (menu bar, new-window profile) |
| `profile-settings.json` | `%APPDATA%\Code - Insiders\User\profiles\<id>\settings.json` | Settings of the `CsPS` profile, where day-to-day work happens |
| `extensions.txt` | — | Extensions installed in the `CsPS` profile |

The `CsPS` profile folder name is a random ID that differs per machine, so `profile-settings.json` is not deployed automatically. With the `CsPS` profile active, run **Preferences: Open User Settings (JSON)** and paste the file in.

Install the extensions with:

```powershell
Get-Content .\strata\40-apps\vscode\extensions.txt | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object { code-insiders --profile CsPS --install-extension $_ }
```

## Configuration Summary

- **Profile**: `CsPS` (opened for every new window)
- **Theme / Icons**: One Dark Pro Night Flat, Material Icon Theme
- **Layout**: side bar on the right, activity bar on top, classic menu bar, no command center
- **Editor**: solid cursor with smooth caret animation, word wrap, linked editing, autosave after delay
- **AI**: Copilot and chat AI features disabled
- **Remote SSH**: host-to-platform map left empty in the repo (fill in locally)
- **Zed parity**: [`../zed/`](../zed/) mirrors this profile's look and extensions
