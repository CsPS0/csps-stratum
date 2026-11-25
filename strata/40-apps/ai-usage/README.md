# AI usage in the top bar

Shows how much of the Claude and Antigravity quota is used, on both machines:

```
Claude 37% used    Antigravity 12% used
```

- **Claude:** the 5-hour window. Shown while Claude Code or the Claude desktop app runs.
- **Antigravity:** the most-used model. Shown while Antigravity runs.
- **Click** for a dropdown with every limit (Claude: 5-hour and 7-day; Antigravity: each model),
  its bar, percent used and reset time. Click again, press Esc or click elsewhere to close it.
- Each one disappears when its app is closed, and takes no room in the bar. The `claude.exe` a
  browser starts for the Claude browser extension (Brave → `cmd` → `claude.exe`) doesn't count as
  Claude being open; it runs whenever the browser does.

| File | Deploys to | Purpose |
|---|---|---|
| `ai_usage.py` | Windows: `%USERPROFILE%\.config\yasb\ai-usage\` · Linux: `~/.local/share/ai-usage/` | Prints the numbers as JSON, or nothing while the app is closed |
| `popup.py` | Windows: `%USERPROFILE%\.config\yasb\ai-usage\` | The click-open dropdown for YASB (its custom widgets have no menu of their own) |
| `plasmoid/org.csps.aiusage/` | Linux: `~/.local/share/plasma/plasmoids/` | KDE Plasma 6 panel widget and its popup |
| `install-kde.sh` | — | Installs the two above on the laptop (`--dry-run`, `--add-to-panel`) |

The Windows bar is set up in [`../yasb/config.yaml`](../yasb/config.yaml) (`claude_usage` and
`antigravity_usage`).

## Where the numbers come from

- **Claude** reads Claude Code's own sign-in (`~/.claude/.credentials.json`) and asks the usage
  endpoint that Claude Code's `/usage` uses. Answers are cached for 5 minutes in
  `%LOCALAPPDATA%\ai-usage\` or `~/.cache/ai-usage/`. If the sign-in has expired, the script runs
  `claude auth status`, which makes Claude Code renew it, at most every 15 minutes. It never writes
  the credentials file itself. Needs Claude Code installed and signed in on that machine.
- **Antigravity** asks the app's local server (`GetUserStatus`) for the per-model quota. The
  standalone app writes the server's port and one-off token to
  `~/.gemini/antigravity/daemon/hub_<port>.json` for local clients; Antigravity IDE on Linux puts
  them on its `agy --hub` command line instead. The token is never stored or printed.

## Install

**Windows (YASB):**

```powershell
New-Item -ItemType Directory -Force "$HOME\.config\yasb\ai-usage" | Out-Null
Copy-Item strata\40-apps\ai-usage\ai_usage.py, strata\40-apps\ai-usage\popup.py "$HOME\.config\yasb\ai-usage\"
```

Then copy [`../yasb/config.yaml`](../yasb/config.yaml) as usual; YASB reloads it by itself.

**Laptop (KDE Plasma 6):**

```sh
cd ~/REPOS/csps-stratum && git pull --ff-only
strata/40-apps/ai-usage/install-kde.sh --dry-run --add-to-panel   # preview
strata/40-apps/ai-usage/install-kde.sh --add-to-panel
```

`--add-to-panel` backs up `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, adds the widget to
the top panel and briefly restarts plasmashell to put it just left of the system tray. Without the
flag the script only installs or updates the files (run it again after a `git pull`).

## Test

```sh
python3 ai_usage.py claude        # {"text": "Claude 37% used", ...}, or nothing if Claude is closed
python3 ai_usage.py antigravity   # nothing while Antigravity is closed
```
