# Environment: Arch Linux laptop

Deployed to `~/.agents/ENV.md` (see `LAPTOP-SETUP.md` step 3). Edit the copy in csps-stratum, not the deployed file.

- Arch Linux with KDE Plasma 6. Repos live in `~/REPOS/<name>`.
- Start Claude Code sessions inside a repo, never in the home folder.
- Interactive shell is zsh. Write scripts for bash (`#!/usr/bin/env bash`, `set -euo pipefail`) unless a file is zsh-specific.
- Check that a tool exists with `command -v <tool> >/dev/null 2>&1` before calling it.
- Use `$HOME` or `~`, never a hard-coded `/home/<name>`. Config goes under `${XDG_CONFIG_HOME:-$HOME/.config}`.
- Quote every path.
- Temporary files go in the agent's own scratch folder, or a `mktemp -d` folder if there is none.
- Packages come from pacman and the AUR. Ask before installing anything system-wide.
- Line endings: LF everywhere.
