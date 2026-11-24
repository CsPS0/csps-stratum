# Environment: Windows desktop

Deployed to `~/.agents/ENV.md` by `hosts/desktop/setup.ps1`. Edit the copy in csps-stratum, not the deployed file.

- Windows 11 Pro. Repos live in `D:\REPOS\<name>`.
- Default shell is PowerShell 7 (`pwsh`). Write PowerShell unless the tool you are using runs Git Bash.
- In PowerShell, do not use POSIX-only commands or flags:
  - `rm -rf` → `Remove-Item -Recurse -Force`
  - `mkdir -p` → `New-Item -ItemType Directory -Force`
  - `head` / `tail` → `Select-Object -First` / `Get-Content -Tail`
  - `which` → `Get-Command`
  - `2>/dev/null` → `2>$null`
  - `VAR=x cmd` → `$env:VAR = 'x'; cmd`
- In Git Bash, use POSIX syntax and `/d/REPOS/...` style paths.
- Use Windows paths (`D:\REPOS\pala`) in PowerShell, configs and docs. Quote every path; user and program folders contain spaces.
- Use `$HOME` or `$env:USERPROFILE`, never a hard-coded `C:\Users\<name>`.
- No `/tmp`. Use the agent's own scratch folder, or `$env:TEMP` if there is none.
- Line endings: LF for `.sh`, `.bash`, `.zsh` and dotfiles; CRLF is fine for `.ps1`, `.bat`, `.cmd`.
