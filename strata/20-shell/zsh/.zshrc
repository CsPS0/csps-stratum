# Created by newuser for 5.9
export PATH=$PATH:$HOME/.local/bin
eval "$(oh-my-posh init zsh --config $HOME/.config/oh-my-posh/oled_monochrome.omp.json)"
# History Settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY          # Share history between sessions
setopt APPEND_HISTORY         # Append to history file
setopt INC_APPEND_HISTORY      # Update history immediately
setopt HIST_IGNORE_DUPS       # Don't record duplicates
setopt HIST_IGNORE_SPACE      # Don't record commands starting with space

# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Suggestion colors and keybinds
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'        # Gray ghost text
ZSH_AUTOSUGGEST_STRATEGY=(history completion) # PowerShell style
bindkey '^f' autosuggest-accept               # Ctrl+F to accept

# Exit-all alias to close the whole WezTerm window/process
if [[ -n "$WEZTERM_PANE" ]]; then
  alias exitall='pkill -TERM -x wezterm-gui'
  alias exit-all='pkill -TERM -x wezterm-gui'
fi

alias h='history 200'
alias up='topgrade'

# Force 24-hour time format
export LC_TIME=C.UTF-8

export PATH="$HOME/.cargo/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# CLI Aliases for bat, btop, eza
alias cat='bat'
alias top='btop'
alias ls='eza --icons=auto'
alias ll='eza -la --icons=auto'
alias tree='eza --tree --icons=auto'

# Zoxide (Smart cd)
eval "$(zoxide init zsh)"

# fzf: Ctrl+T files, Alt+C dirs (Ctrl+R is taken over by atuin below)
source <(fzf --zsh)

# Atuin: searchable shell history on Ctrl+R (Up arrow left as normal)
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# Starship Minimalist Prompt Init
eval "$(starship init zsh)"
alias dia='GTK_THEME=WhiteSur-Light dia'

# US formats in terminals only. It used to be in ~/.zshenv, where the login shell passed it
# to the whole Plasma session and overrode the Hungarian time formats (24h, year first).
export LC_ALL="en_US.UTF-8"
