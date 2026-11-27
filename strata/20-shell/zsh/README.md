# zsh and Starship (laptop)

The laptop's interactive shell (Arch Linux, KDE Plasma 6). Copied from the laptop on 27 November
2026, with `/home/<user>` replaced by `$HOME`.

| File | Deploys to | Purpose |
|---|---|---|
| [`.zshrc`](.zshrc) | `~/.zshrc` | History, autosuggestions and syntax highlighting, aliases, zoxide, fzf, atuin, then the prompt |
| [`../starship/starship.toml`](../starship/starship.toml) | `~/.config/starship.toml` | Minimal OLED Monochrome prompt: user (only over SSH or as root), host, folder, git branch and status, `❯` |

`.zshrc` starts Oh My Posh and then Starship. Both set the prompt, and Starship runs last, so it is
the prompt you see. The Oh My Posh line is a leftover and can go.

## Needs

`zsh`, `starship`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `eza`, `bat`, `btop`, `zoxide`,
`fzf`, `atuin`, `topgrade` (pacman), and `oh-my-posh` in `~/.local/bin` while its line stays.

## Apply

```sh
cd ~/REPOS/csps-stratum
for f in ~/.zshrc ~/.config/starship.toml; do [ -e "$f" ] && cp -a "$f" "$f.$(date +%Y%m%d-%H%M%S).bak"; done
cp strata/20-shell/zsh/.zshrc ~/.zshrc
mkdir -p ~/.config && cp strata/20-shell/starship/starship.toml ~/.config/starship.toml
```
