# Applying the 2026-11-24 agent setup on the laptop (Arch Linux)

Nothing here has been run on the laptop. Commands are for zsh/bash on the laptop unless marked.
No tokens, auth headers or machine-specific paths: set `REPOS` once and everything else uses `$HOME` and `$REPOS`.

```sh
export REPOS="$HOME/REPOS"   # the laptop's repo root; change if yours differs
```

## 0. Before you start

1. **On the desktop:** commit and push the csps-stratum snapshot changes (`strata/30-dev/ai/*`, `hosts/desktop/*`). The laptop gets the snapshot from git.
2. **On the laptop:** `git -C "$REPOS/csps-stratum" pull`.
3. Back up, never delete. Copy what you will edit:
   ```sh
   B="$HOME/agent-config-backup/$(date +%F_%H%M)"; mkdir -p "$B"
   cp -a ~/.claude/settings.json ~/.claude.json ~/.claude/CLAUDE.md ~/.claude/plugins/*.json "$B"/ 2>/dev/null
   cp -a ~/.gemini/config/config.json ~/.gemini/config/mcp_config.json ~/.gemini/antigravity-cli/settings.json "$B"/ 2>/dev/null
   cp -a ~/.config/git/ignore "$B"/gitignore 2>/dev/null
   ```
   Keep `$B` out of synced folders: `.claude.json` and `mcp_config.json` can hold auth headers.

## 1. What does not carry over from Windows

| Piece | Why | What to do on the laptop |
|---|---|---|
| Guard hook `guard-destructive.ps1` | Its path checks assume Windows drives; on Linux it would block every absolute path | Install the Python port instead (step 5, "Guard hook") |
| `hosts/desktop/ENV.md` | Windows 11 and PowerShell rules | Deploy `hosts/laptop/ENV.md` instead (step 3) |
| Roblox hooks and `Roblox_Studio` MCP | Roblox Studio does not run natively on Linux | Skip (recipe in step 7 for reference) |
| `horizon` MCP | Points to the Windows launcher | Skip unless the laptop has its own Horizon install |
| PowerShell permission rules | Harmless, but only fire if a PowerShell tool exists | Keep or drop |
| Antigravity terminal sandbox | The desktop check was for Windows 11 24H2+ | Check the Linux requirement on antigravity.google/docs/sandbox first |

## 2. Global git ignore

```sh
mkdir -p ~/.config/git
grep -qx '\*\*/.claude/settings.local.json' ~/.config/git/ignore 2>/dev/null || echo '**/.claude/settings.local.json' >> ~/.config/git/ignore
grep -qx 'HANDOFF.md' ~/.config/git/ignore 2>/dev/null || echo 'HANDOFF.md' >> ~/.config/git/ignore
git config --global core.excludesFile   # empty output means the default ~/.config/git/ignore is used
```

## 3. Shared rules (`~/.agents/RULES.md`) and environment (`~/.agents/ENV.md`)

The rules are split in two:

- `~/.agents/RULES.md` holds the OS-neutral rules (tool preferences, ownership, handoff, git, secrets, shared skills). It is the same file on both machines and is not in git: copy it from the desktop as is (scp), with no edits.
- `~/.agents/ENV.md` holds this machine's environment rules. It is deployed from csps-stratum's `hosts/laptop/ENV.md` (Arch Linux, KDE, zsh/bash). Edit the copy in csps-stratum, then deploy it again.

```sh
mkdir -p ~/.agents
# RULES.md: copy it from the desktop's ~/.agents/RULES.md (scp), unchanged
[ -e ~/.agents/ENV.md ] && cp -a ~/.agents/ENV.md "$B/ENV.md"
cp "$REPOS/csps-stratum/hosts/laptop/ENV.md" ~/.agents/ENV.md
```

Then wire both files into both agents:

```sh
grep -q '@~/.agents/RULES.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n# Shared rules (Claude Code and Antigravity)\n@~/.agents/RULES.md\n' >> ~/.claude/CLAUDE.md
grep -q '@~/.agents/ENV.md' ~/.claude/CLAUDE.md || printf '@~/.agents/ENV.md\n' >> ~/.claude/CLAUDE.md
[ -e ~/.gemini/GEMINI.md ] && cp -a ~/.gemini/GEMINI.md "$B/GEMINI.md"
grep -q 'agents/ENV.md' ~/.gemini/GEMINI.md 2>/dev/null || printf '# Global rules for Antigravity\n\nThe shared rules for both agents live in ~/.agents/RULES.md, and this machine'"'"'s environment rules in ~/.agents/ENV.md. Both are included here:\n\n@[Shared rules](~/.agents/RULES.md)\n\n@[Environment](~/.agents/ENV.md)\n' > ~/.gemini/GEMINI.md
```

Check: in a fresh `claude` session, `/memory` lists both `~/.agents/RULES.md` and `~/.agents/ENV.md`, and the ENV.md heading reads "Environment: Arch Linux laptop".

## 4. Shared skills

```sh
mkdir -p ~/.agents/skills
# anti-slop-design: clone it if it is not there yet
[ -d ~/.agents/skills/anti-slop-design ] || git clone https://github.com/wwewtech/anti-slop-design ~/.agents/skills/anti-slop-design
# trello-use: copy ~/.agents/skills/trello-use from the desktop (scp -r)
# security-audit: same command as the desktop. -a codex puts it only in ~/.agents/skills (codex's global
# skills folder in this CLI); -y skips the prompts; telemetry off.
[ -d ~/.agents/skills/security-audit ] || DISABLE_TELEMETRY=1 npx --yes skills@1.9.0 add \
  https://github.com/cloudflare/security-audit-skill --skill security-audit --global -a codex -y
# The CLI installs the repo's current default branch, so check it is the reviewed commit:
grep -A8 '"security-audit"' ~/.agents/.skill-lock.json | grep '"commit"'
#   expected: c1c8a8c1471069fb0e188eeaff69b8e8db6564a8
#   anything else: stop, review the new commits on github.com/cloudflare/security-audit-skill first
# then link all three skills into both agents
for s in anti-slop-design trello-use security-audit; do
  for d in ~/.claude/skills ~/.gemini/config/skills; do
    mkdir -p "$d"
    if [ -e "$d/$s" ] && [ ! -L "$d/$s" ]; then mv "$d/$s" "$B/skill-$s-$(basename "$(dirname "$d")")"; fi
    [ -L "$d/$s" ] || ln -s ~/.agents/skills/$s "$d/$s"
  done
done
```

## 5. Claude Code

**Plugins** (all user scope):

```sh
for p in headroom@headroom-marketplace serena playwright browser-use context7 exa firecrawl linear gitlab atlassian \
         feature-dev code-simplifier skill-creator claude-code-setup claude-security \
         deep-plan@piercelamb-plugins deep-project@piercelamb-plugins deep-implement@piercelamb-plugins; do
  case "$p" in *@*) id="$p" ;; *) id="$p@claude-plugins-official" ;; esac
  claude plugin uninstall "$id" --keep-data || true   # "not installed" is fine
done
claude plugin marketplace remove headroom-marketplace || true
claude plugin marketplace remove piercelamb-plugins || true
claude plugin disable claude-mem@thedotmack
claude plugin disable ponytail@ponytail
claude plugin list   # expect: superpowers, frontend-design, github, vercel, commit-commands, claude-md-management, LSPs enabled;
                     # claude-mem, ponytail and security-guidance installed but disabled; claude-security gone
```

Back up cache folders first if you want them: `cp -a ~/.claude/plugins/cache "$B/plugins-cache"`.

**claude-mem worker:** `pgrep -af claude-mem` and `ss -ltnp | grep 37777`. Stop it with `kill <pid>` if it runs. Its data in `~/.claude-mem` stays.

**`~/.claude/settings.json`:** merge these blocks from `$REPOS/csps-stratum/strata/30-dev/ai/claude-settings.json` by hand; keep your existing keys:
- `permissions.deny` and `permissions.ask` (all of them; the PowerShell ones are optional on Linux).
- On the laptop only, also add `Bash(sudo *)` to `permissions.ask`. This covers the guard hook's known limit: options after `sudo` (such as `sudo -u root rm -rf /x`) hide the command from it, so every sudo command asks first.

  ```json
  {
    "permissions": {
      "ask": [
        "Bash(sudo *)"
      ]
    }
  }
  ```

  Add it to your existing `ask` list rather than replacing the list.
- `skipDangerousModePermissionPrompt: false`.
- `autoMode`. Change two `environment` lines for the laptop: "Primary use: ... on Arch Linux (Flutter, web, Minecraft modding)" and "Local repos: ~/REPOS/<name> ...". Put your private repo names into the "Repository visibility" line (the snapshot leaves them out on purpose).
- **Do not copy the snapshot's `hooks.PreToolUse` block**: it runs the Windows `.ps1`. Use the Linux block below instead.

**Guard hook (Linux port).** It blocks git force pushes and recursive deletes outside `$HOME/REPOS` and the Claude scratch directory (`${TMPDIR:-/tmp}/claude`). It needs `python3`.

- **Fails closed:** malformed input or an internal error also blocks the command, with a "guard-destructive: internal error" message.
- **Variables:** in `rm` targets it fills in `$HOME`, `$TMPDIR`, `$REPOS` and `~` from its own environment. `$REPOS` resolves only if it is set in the environment Claude Code starts with. Otherwise `rm -rf "$REPOS/..."` is blocked as unresolved, which is safe.

**Order matters:** the hook blocks every Bash command if it is broken, so run the test suite on the laptop first. Add the hooks block to `settings.json` only after it prints `failed: 0`.

```sh
command -v python3 >/dev/null 2>&1 || echo "python3 missing: install it first (pacman -S python)"
mkdir -p ~/.claude/hooks
[ -e ~/.claude/hooks/guard-destructive.py ] && cp -a ~/.claude/hooks/guard-destructive.py "$B/"
cp "$REPOS/csps-stratum/strata/30-dev/ai/hooks/guard-destructive.py" ~/.claude/hooks/
chmod +x ~/.claude/hooks/guard-destructive.py
# 1. The suite must pass on the laptop BEFORE the hooks block goes into settings.json:
if bash "$REPOS/csps-stratum/strata/30-dev/ai/hooks/test-guard-destructive.sh" > "$B/guard-tests.txt" 2>&1; then
  tail -n 1 "$B/guard-tests.txt"   # expect: passed: 61  failed: 0  of 61
else
  echo "guard hook tests FAILED: do not add the hooks block; see $B/guard-tests.txt"
fi
```

2. Only if the suite passed, add this to `~/.claude/settings.json` (merge it into an existing `hooks` object; keep other hooks):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$HOME/.claude/hooks/guard-destructive.py\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Check the scratch directory once: in a `claude` session, the system prompt's "Scratchpad directory" line should start with `${TMPDIR:-/tmp}/claude`. If it is somewhere else, the hook will block cleanups there. Add that folder through the `env` block of `~/.claude/settings.json`: `"env": { "GUARD_ALLOW_ROOTS": "<that folder>" }`, colon-separated for more than one. I have not confirmed that hook processes inherit `env` from settings, so re-run the live test below afterwards.

Live test: in a fresh `claude` session, ask it to run `rm -rf /tmp/guard-hook-test-does-not-exist`. It should be refused with "Blocked by guard-destructive hook".
- Check JSON after editing: `python -m json.tool ~/.claude/settings.json >/dev/null && echo ok`.

**claude.ai connectors:** block Gmail, Google Calendar, Google Drive, Slack and the Vercel connector in Claude Code without disconnecting them from your account, so they keep working in the claude.ai chat. Trello, Figma, Claude Docs and the github and vercel plugins stay on. On the laptop, Claude Code runs in the terminal, so two layers apply. Merge both into `~/.claude/settings.json`; keep your existing entries:

```json
{
  "permissions": {
    "deny": [
      "mcp__claude_ai_Slack__*",
      "mcp__claude_ai_Google_Calendar__*",
      "mcp__claude_ai_Google_Drive__*",
      "mcp__claude_ai_Gmail__*",
      "mcp__claude_ai_Vercel__*",
      "mcp__claude-in-chrome__*"
    ]
  },
  "deniedMcpServers": [
    { "serverName": "claude.ai Slack" },
    { "serverName": "claude.ai Google Calendar" },
    { "serverName": "claude.ai Google Drive" },
    { "serverName": "claude.ai Gmail" },
    { "serverName": "claude.ai Vercel" }
  ]
}
```

- **`deniedMcpServers`** stops the terminal from loading these connectors at all. A session then prints "claude.ai MCP servers blocked by enterprise policy: …", which is expected.
- **The `mcp__claude_ai_*` deny rules** are a second layer, in case a connector is loaded some other way.
- **`mcp__claude-in-chrome__*`** blocks every Claude in Chrome tool, so Claude Code cannot reach those services through the browser either. The server has the same name in the terminal (`claude --chrome`) and the desktop app. The desktop app's built-in browser (`mcp__Claude_Browser__*`) is a separate server and keeps working. Check with `claude -p --chrome "list your MCP tool prefixes"`: `claude-in-chrome` must not appear.
- **The desktop app (Windows/macOS) is not covered by either.** It delivers connectors in-process, so only permission rules on the connector's ID-based server name reach them: `mcp__<connector-id>__*`. The snapshot holds placeholders for those; the desktop's real IDs are in its `~/.claude/settings.json`.
- **Check:** `claude mcp list` should show Claude Docs, Trello and Figma as connected, plus the two plugins, but not Gmail, Google Calendar, Google Drive, Slack or Vercel.

## 6. Per-repo, git-ignored pieces (not in the snapshot)

**ponytail in the school repos.** Create the file in each school repo. Replace `<school-repo>` with the folder name of your private school repo:

```sh
for r in "$REPOS/My-School-Projects" "$REPOS/<school-repo>"; do
  [ -d "$r" ] || { echo "skipped, not found: $r"; continue; }
  mkdir -p "$r/.claude"
  [ -e "$r/.claude/settings.local.json" ] && cp -a "$r/.claude/settings.local.json" "$B/$(basename "$r").settings.local.json"
  printf '{\n    "enabledPlugins": {\n        "ponytail@ponytail": true\n    }\n}\n' > "$r/.claude/settings.local.json"
done
```

If a repo already has a `settings.local.json` with other keys, add the `enabledPlugins` entry to it by hand instead of overwriting.

**dart MCP, local to the Flutter repo.** Run in a terminal (not inside a Claude session), from inside the repo:

```sh
if [ -d "$REPOS/pala" ]; then
  cd "$REPOS/pala"
  claude mcp add-json -s local dart '{"type":"stdio","command":"dart","args":["mcp-server"],"env":{}}'
  claude mcp list                     # dart shows here
  cd ~ && claude mcp remove dart -s user 2>/dev/null; claude mcp list   # dart must not show here
else
  echo "skipped, not found: $REPOS/pala (user-scope dart left as it is)"
fi
```

## 7. Windows-only, for reference (Neumann-Survival-Week)

Skip these on Arch. On a Windows machine with Roblox Studio, they are:

`<repo>\.claude\settings.local.json`:

```json
{
    "hooks": {
        "PostToolUse": [{ "matcher": "mcp__Roblox_Studio__.*", "hooks": [{ "type": "command", "command": "\"C:\\Users\\<you>\\AppData\\Local\\Roblox\\StudioMCPHook.bat\" roblox-data-access claude_code tool", "timeout": 5 }] }],
        "PostToolUseFailure": [{ "matcher": "mcp__Roblox_Studio__.*", "hooks": [{ "type": "command", "command": "\"C:\\Users\\<you>\\AppData\\Local\\Roblox\\StudioMCPHook.bat\" roblox-data-access claude_code tool", "timeout": 5 }] }],
        "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "\"C:\\Users\\<you>\\AppData\\Local\\Roblox\\StudioMCPHook.bat\" roblox-data-access claude_code prompt", "timeout": 5 }] }],
        "Stop": [{ "hooks": [{ "type": "command", "command": "\"C:\\Users\\<you>\\AppData\\Local\\Roblox\\StudioMCPHook.bat\" roblox-data-access claude_code stop", "timeout": 5 }] }]
    }
}
```

Replace `<you>` with your Windows user folder name. Keep the full path: hooks may run in Git Bash, which does not expand `%LOCALAPPDATA%`.

`Roblox_Studio` MCP, local scope, from inside the repo in PowerShell:

```powershell
claude mcp add-json -s local Roblox_Studio '{"type":"stdio","command":"cmd.exe","args":["/c","cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"],"env":{}}'
```

## 8. Antigravity

```sh
agy mcp list
for m in context7 dart-mcp-server browser-use playwright; do agy mcp remove "$m" || true; done
for p in science science-overview google_maps_platform google-developer-knowledge gcalendar gdocs gdrive gsheets gslides; do agy plugin disable "$p" || true; done
agy plugin list
```

`~/.gemini/antigravity-cli/settings.json`: merge by hand, keep your keys:
- `"allowNonWorkspaceAccess": false`
- `"trustedWorkspaces"`: only your repo root and the project folders you trust; never `$HOME` or `/`.
- `"permissions": { "deny": [...] }` with Linux targets, for example `read_file(<home>/.ssh)`, `write_file(<home>/.ssh)`, `command(git push --force)`, `command(git push -f)`, `command(rm -rf)`, `command(rm -fr)`. Replace `<home>` with the output of `echo $HOME` (the docs only show absolute paths).
- `"enableTerminalSandbox": true` only after checking the Linux requirement in the sandbox docs.

In the Antigravity app: **Settings > General > Global Permissions > Permission Preset** → Default or Auto (not Turbo). **Settings > Application > Enable Remote Control** → off.

## 9. Check

- `claude plugin list`, `claude mcp list` (from `~`, from `$REPOS/pala`, from a school repo), `agy mcp list`, `agy plugin list`.
- Fresh Claude session in a school repo: ponytail skills listed; `/memory` shows `~/.agents/RULES.md`.
- Antigravity: ask "Which agent owns Roblox work, according to my rules?" → Claude Code.
- Restart both apps.
