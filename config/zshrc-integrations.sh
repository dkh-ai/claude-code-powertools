# >>> claude-code-powertools >>>
# Modern CLI Tools — managed by claude-code-powertools
# https://github.com/dkh-ai/claude-code-powertools

# fzf — fuzzy finder
# Ctrl+R: history search, Ctrl+T: file picker, Alt+C: cd to dir
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# zoxide — smart cd (learns your directories)
# z <query>: jump to dir, zi: interactive picker
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# bat — modern cat with syntax highlighting
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# eza — modern ls with git integration
if command -v eza &>/dev/null; then
    alias ls='eza'
    alias ll='eza -la --git --icons'
    alias lt='eza -T --level=2 --icons --git-ignore'
    alias la='eza -a'
fi

# lazygit — git TUI
if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
fi
# <<< claude-code-powertools <<<
