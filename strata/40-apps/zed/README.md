# Zed Editor Stratum

Configuration profile for the [Zed editor](https://zed.dev/), tuned to look and behave like the VS Code Insiders `CsPS` profile in [`../vscode/`](../vscode/).

---

## Files

| File | Deploys to (Windows) | Purpose |
|---|---|---|
| `settings.json` | `%APPDATA%\Zed\settings.json` | Editor, layout, terminal, and extension settings |
| `themes/one-dark-pro-night-flat.json` | `%APPDATA%\Zed\themes\` | Zed port of VS Code's *One Dark Pro Night Flat* (required by `settings.json`) |
| `extensions.txt` | — | Installed Zed extensions, for reference |

## Configuration Highlights

- **Theme**: `One Dark Pro Night Flat`, converted from the VS Code theme (same UI colors, syntax colors and bracket pair colors)
- **Icon Theme**: `Material Icon Theme`
- **Keymap**: `VSCode` base bindings (VS Code has no custom keybindings, so this is an exact match)
- **Typography**: `JetBrainsMono NF` 15 in the editor and 14 in the terminal, Segoe UI 14 for the interface
- **Feel**: smooth cursor animation (VS Code `cursorSmoothCaretAnimation`), solid non-blinking cursor, sticky scroll, scroll past last line, window stays open when the last tab closes, preview tabs
- **Layout**: project, git, outline and collaboration panels docked right (VS Code side bar on the right)
- **VS Code extension equivalents**: inline diagnostics (Error Lens), indent background colouring (indent-rainbow), inline git blame (GitLens), linked tag editing (Auto Rename Tag)
- **Saving**: autosave after 1 s; format-on-save, whitespace trimming and inlay hints off (VS Code defaults)
- **AI**: disabled (`disable_ai`, edit predictions off), matching `chat.disableAIFeatures` in VS Code
- **Telemetry**: diagnostics, metrics, and retention all disabled

## Extensions

`settings.json` auto-installs the Zed equivalents of VS Code extensions (Svelte, Haskell, R, Docker Compose, Jinja2, Nunjucks, Django, Comment, Mermaid, GitHub Actions, Discord Presence). The matching VS Code side is in [`../vscode/extensions.txt`](../vscode/extensions.txt).
