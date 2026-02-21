#!/usr/bin/env bash
# claude-code-powertools — Interactive Installer
# Installs and configures CLI tools that enhance Claude Code and your terminal.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/dkh-ai/claude-code-powertools/main/install.sh | bash
#   bash install.sh [--yes] [--dry-run] [--preset <name>] [--help]
#
# Requires: macOS, Homebrew (will offer to install)
# Bash 3.2 compatible (no associative arrays)

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

VERSION="1.0.0"
MARKER_ZSHRC_BEGIN="# >>> claude-code-powertools >>>"
MARKER_ZSHRC_END="# <<< claude-code-powertools <<<"
MARKER_CLAUDE_BEGIN="<!-- claude-code-powertools:begin -->"
MARKER_CLAUDE_END="<!-- claude-code-powertools:end -->"

ZSHRC="$HOME/.zshrc"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# ── Colors ─────────────────────────────────────────────────────────────

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BLUE='\033[34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()  { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}!${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*"; }
dim()   { echo -e "${DIM}$*${RESET}"; }

# ── Tool Catalog (parallel indexed arrays — bash 3.2 safe) ────────────
# Each tool has 5 fields across parallel arrays:
#   TOOL_NAME  TOOL_BREW  TOOL_CMD  TOOL_CAT  TOOL_DESC

TOOL_NAME=()
TOOL_BREW=()
TOOL_CMD=()
TOOL_CAT=()
TOOL_DESC=()

#  0: tree
TOOL_NAME+=("tree");        TOOL_BREW+=("tree");        TOOL_CMD+=("tree");       TOOL_CAT+=("claude"); TOOL_DESC+=("Project structure overview")
#  1: yq
TOOL_NAME+=("yq");          TOOL_BREW+=("yq");          TOOL_CMD+=("yq");         TOOL_CAT+=("claude"); TOOL_DESC+=("YAML/TOML/XML parsing and filtering")
#  2: shellcheck
TOOL_NAME+=("shellcheck");  TOOL_BREW+=("shellcheck");  TOOL_CMD+=("shellcheck"); TOOL_CAT+=("claude"); TOOL_DESC+=("Shell script static analysis")
#  3: fd
TOOL_NAME+=("fd");          TOOL_BREW+=("fd");          TOOL_CMD+=("fd");         TOOL_CAT+=("claude"); TOOL_DESC+=("Modern file finder (replaces find)")
#  4: ripgrep
TOOL_NAME+=("ripgrep");     TOOL_BREW+=("ripgrep");     TOOL_CMD+=("rg");         TOOL_CAT+=("claude"); TOOL_DESC+=("Fast code search for Bash pipelines")
#  5: scc
TOOL_NAME+=("scc");         TOOL_BREW+=("scc");         TOOL_CMD+=("scc");        TOOL_CAT+=("claude"); TOOL_DESC+=("Codebase statistics by language")
#  6: difftastic
TOOL_NAME+=("difftastic");  TOOL_BREW+=("difftastic");  TOOL_CMD+=("difft");      TOOL_CAT+=("claude"); TOOL_DESC+=("AST-aware structural git diff")
#  7: jq
TOOL_NAME+=("jq");          TOOL_BREW+=("jq");          TOOL_CMD+=("jq");         TOOL_CAT+=("claude"); TOOL_DESC+=("JSON parsing and filtering")
#  8: fzf
TOOL_NAME+=("fzf");         TOOL_BREW+=("fzf");         TOOL_CMD+=("fzf");        TOOL_CAT+=("user");   TOOL_DESC+=("Fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)")
#  9: zoxide
TOOL_NAME+=("zoxide");      TOOL_BREW+=("zoxide");      TOOL_CMD+=("zoxide");     TOOL_CAT+=("user");   TOOL_DESC+=("Smart cd that learns your directories")
# 10: eza
TOOL_NAME+=("eza");         TOOL_BREW+=("eza");         TOOL_CMD+=("eza");        TOOL_CAT+=("user");   TOOL_DESC+=("Modern ls with git and icons")
# 11: lazygit
TOOL_NAME+=("lazygit");     TOOL_BREW+=("lazygit");     TOOL_CMD+=("lazygit");    TOOL_CAT+=("user");   TOOL_DESC+=("Full git TUI")
# 12: bat
TOOL_NAME+=("bat");         TOOL_BREW+=("bat");         TOOL_CMD+=("bat");        TOOL_CAT+=("user");   TOOL_DESC+=("cat with syntax highlighting")
# 13: imagemagick
TOOL_NAME+=("imagemagick"); TOOL_BREW+=("imagemagick"); TOOL_CMD+=("magick");     TOOL_CAT+=("user");   TOOL_DESC+=("Batch image processing")
# 14: htop
TOOL_NAME+=("htop");        TOOL_BREW+=("htop");        TOOL_CMD+=("htop");       TOOL_CAT+=("user");   TOOL_DESC+=("Interactive process monitor")

TOOL_COUNT=${#TOOL_NAME[@]}

# ── Selection state ────────────────────────────────────────────────────
# 1 = selected, 0 = not selected
TOOL_SELECTED=()
for (( i=0; i<TOOL_COUNT; i++ )); do
    TOOL_SELECTED+=(1)
done

# ── Result tracking ───────────────────────────────────────────────────

result_installed=""
result_skipped=""
result_configured=""
result_failed=""

result_add() {
    local list_name="$1"
    local item="$2"
    local current
    current="$(eval echo "\$$list_name")"
    if [ -z "$current" ]; then
        eval "$list_name=\"$item\""
    else
        eval "$list_name=\"$current|$item\""
    fi
}

result_print() {
    local label="$1" color="$2" prefix="$3" items="$4"
    if [ -z "$items" ]; then return; fi
    echo ""
    echo -e "${color}${label}:${RESET}"
    local IFS='|'
    for item in $items; do
        echo -e "  ${prefix} ${item}"
    done
}

# ── CLI Arguments ──────────────────────────────────────────────────────

OPT_YES=false
OPT_DRY_RUN=false
OPT_PRESET=""
OPT_HELP=false

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y)       OPT_YES=true ;;
            --dry-run|-n)   OPT_DRY_RUN=true ;;
            --preset|-p)
                shift
                if [ $# -eq 0 ]; then
                    error "--preset requires a value: all, claude, user, minimal"
                    exit 1
                fi
                OPT_PRESET="$1"
                ;;
            --help|-h)      OPT_HELP=true ;;
            *)
                error "Unknown option: $1"
                echo "  Run with --help for usage."
                exit 1
                ;;
        esac
        shift
    done
}

show_help() {
    cat <<'HELP'

  claude-code-powertools — Interactive Installer

  Usage:
    bash install.sh [options]

  Options:
    --yes, -y           Skip confirmations (auto-accept all)
    --dry-run, -n       Show what would be done without making changes
    --preset, -p NAME   Pre-select tools: all, claude, user, minimal
    --help, -h          Show this help

  Presets:
    all       All 15 tools (default)
    claude    8 tools that enhance Claude Code
    user      7 tools that enhance your terminal
    minimal   tree, jq, fd, shellcheck (essential 4)

  Examples:
    bash install.sh                         # Interactive menu
    bash install.sh --preset claude --yes   # Non-interactive, Claude tools only
    bash install.sh --dry-run               # Preview without changes

HELP
}

# ── Preflight Checks ──────────────────────────────────────────────────

preflight() {
    # Refuse root
    if [ "$(id -u)" -eq 0 ]; then
        error "Do not run as root. Homebrew requires a normal user."
        exit 1
    fi

    # macOS only
    if [ "$(uname -s)" != "Darwin" ]; then
        error "This installer is for macOS only."
        echo "  Linux users can install these tools via their package manager."
        exit 1
    fi

    # Detect architecture
    ARCH="$(uname -m)"
    info "macOS $(sw_vers -productVersion) ($ARCH)"

    # Check/install Homebrew
    if ! command -v brew &>/dev/null; then
        warn "Homebrew not found."
        if $OPT_YES || confirm "Install Homebrew?"; then
            if $OPT_DRY_RUN; then
                dim "  [dry-run] Would install Homebrew"
            else
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Add brew to PATH for this session (Apple Silicon)
                if [ -f /opt/homebrew/bin/brew ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            fi
        else
            error "Homebrew is required. Aborting."
            exit 1
        fi
    fi
    info "Homebrew $(brew --version | head -1 | awk '{print $2}')"
}

# ── TTY Detection ─────────────────────────────────────────────────────

detect_tty() {
    if [ ! -t 0 ]; then
        # Piped input (curl | bash) — force non-interactive
        OPT_YES=true
        dim "  Non-interactive mode (piped input detected)"
    fi
}

# ── Confirm Helper ────────────────────────────────────────────────────

confirm() {
    if $OPT_YES; then return 0; fi
    local prompt="$1"
    echo -en "${YELLOW}${prompt} [y/N]:${RESET} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ── Apply Preset ──────────────────────────────────────────────────────

apply_preset() {
    local preset="$1"
    case "$preset" in
        all|a)
            for (( i=0; i<TOOL_COUNT; i++ )); do TOOL_SELECTED[i]=1; done
            ;;
        claude|claude-code|c)
            for (( i=0; i<TOOL_COUNT; i++ )); do
                if [ "${TOOL_CAT[$i]}" = "claude" ]; then
                    TOOL_SELECTED[i]=1
                else
                    TOOL_SELECTED[i]=0
                fi
            done
            ;;
        user|u)
            for (( i=0; i<TOOL_COUNT; i++ )); do
                if [ "${TOOL_CAT[$i]}" = "user" ]; then
                    TOOL_SELECTED[i]=1
                else
                    TOOL_SELECTED[i]=0
                fi
            done
            ;;
        minimal|m)
            for (( i=0; i<TOOL_COUNT; i++ )); do TOOL_SELECTED[i]=0; done
            # tree=0, fd=3, shellcheck=2, jq=7
            TOOL_SELECTED[0]=1
            TOOL_SELECTED[2]=1
            TOOL_SELECTED[3]=1
            TOOL_SELECTED[7]=1
            ;;
        *)
            error "Unknown preset: $preset"
            echo "  Valid presets: all, claude, user, minimal"
            exit 1
            ;;
    esac
}

# ── Interactive Menu ──────────────────────────────────────────────────

show_menu() {
    echo ""
    echo -e "  ${BOLD}Select tools to install${RESET}"
    echo -e "  ${DIM}Type a number to toggle, preset letter, or Enter to confirm${RESET}"
    echo ""

    # Claude Code tools
    echo -e "  ${BLUE}${BOLD}For Claude Code:${RESET}"
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_CAT[$i]}" != "claude" ]; then continue; fi
        local mark=" "
        if [ "${TOOL_SELECTED[$i]}" -eq 1 ]; then mark="${GREEN}*${RESET}"; fi
        local status=""
        if command -v "${TOOL_CMD[$i]}" &>/dev/null; then status="${DIM}(installed)${RESET}"; fi
        printf "  %2d) [%b] %-14s %s %b\n" "$((i+1))" "$mark" "${TOOL_NAME[$i]}" "${TOOL_DESC[$i]}" "$status"
    done

    echo ""
    echo -e "  ${BLUE}${BOLD}For You:${RESET}"
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_CAT[$i]}" != "user" ]; then continue; fi
        local mark=" "
        if [ "${TOOL_SELECTED[$i]}" -eq 1 ]; then mark="${GREEN}*${RESET}"; fi
        local status=""
        if command -v "${TOOL_CMD[$i]}" &>/dev/null; then status="${DIM}(installed)${RESET}"; fi
        printf "  %2d) [%b] %-14s %s %b\n" "$((i+1))" "$mark" "${TOOL_NAME[$i]}" "${TOOL_DESC[$i]}" "$status"
    done

    echo ""
    echo -e "  ${DIM}Presets: a=all  c=claude-only  u=user-only  m=minimal  n=none${RESET}"
}

interactive_menu() {
    if $OPT_YES; then return; fi

    while true; do
        show_menu
        echo ""
        echo -en "  ${BOLD}Toggle [1-${TOOL_COUNT}] or preset [a/c/u/m/n], Enter to confirm:${RESET} "
        read -r input

        # Empty = confirm
        if [ -z "$input" ]; then
            break
        fi

        case "$input" in
            a) apply_preset all ;;
            c) apply_preset claude ;;
            u) apply_preset user ;;
            m) apply_preset minimal ;;
            n) for (( i=0; i<TOOL_COUNT; i++ )); do TOOL_SELECTED[i]=0; done ;;
            *)
                # Try to parse as number
                if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "$TOOL_COUNT" ]; then
                    local idx=$((input - 1))
                    if [ "${TOOL_SELECTED[idx]}" -eq 1 ]; then
                        TOOL_SELECTED[idx]=0
                    else
                        TOOL_SELECTED[idx]=1
                    fi
                else
                    warn "Invalid input: $input"
                fi
                ;;
        esac
    done
}

# ── Count Selected ────────────────────────────────────────────────────

count_selected() {
    local count=0
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_SELECTED[$i]}" -eq 1 ]; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# ── Install Tools ─────────────────────────────────────────────────────

install_tools() {
    local selected
    selected="$(count_selected)"
    if [ "$selected" -eq 0 ]; then
        warn "No tools selected. Skipping installation."
        return
    fi

    echo ""
    echo -e "  ${BOLD}Installing $selected tool(s)...${RESET}"
    echo ""

    # Collect brew packages to install (skip already installed)
    local to_install=""
    local to_install_count=0

    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_SELECTED[$i]}" -ne 1 ]; then continue; fi

        if command -v "${TOOL_CMD[$i]}" &>/dev/null; then
            local ver=""
            # Try to get version (best effort)
            ver="$("${TOOL_CMD[$i]}" --version 2>/dev/null | head -1 || echo "")"
            result_add result_skipped "${TOOL_NAME[$i]} ${DIM}${ver}${RESET}"
        else
            to_install="${to_install} ${TOOL_BREW[$i]}"
            to_install_count=$((to_install_count + 1))
        fi
    done

    if [ "$to_install_count" -eq 0 ]; then
        info "All selected tools already installed."
        return
    fi

    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would run: brew install${to_install}"
        for pkg in $to_install; do
            result_add result_installed "${pkg} (dry-run)"
        done
        return
    fi

    # Try batch install first (word splitting is intentional)
    echo -e "  ${DIM}brew install${to_install}${RESET}"
    # shellcheck disable=SC2086
    if brew install $to_install 2>/dev/null; then
        for pkg in $to_install; do
            result_add result_installed "$pkg"
        done
    else
        # Fallback: one by one
        warn "Batch install failed. Trying one by one..."
        for pkg in $to_install; do
            if brew install "$pkg" 2>/dev/null; then
                result_add result_installed "$pkg"
            else
                result_add result_failed "$pkg"
                error "Failed to install $pkg"
            fi
        done
    fi
}

# ── Configure .zshrc ──────────────────────────────────────────────────

configure_zshrc() {
    # Check if any user-category tools are selected
    local has_user_tools=false
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_SELECTED[$i]}" -eq 1 ] && [ "${TOOL_CAT[$i]}" = "user" ]; then
            has_user_tools=true
            break
        fi
    done

    if ! $has_user_tools; then
        dim "  No user tools selected — skipping .zshrc configuration"
        return
    fi

    # Generate the zshrc block dynamically
    local block=""
    block="${MARKER_ZSHRC_BEGIN}"
    block="${block}
# Modern CLI Tools — managed by claude-code-powertools
# https://github.com/dkh-ai/claude-code-powertools"

    # fzf
    if [ "${TOOL_SELECTED[8]}" -eq 1 ]; then
        block="${block}

# fzf — fuzzy finder
# Ctrl+R: history search, Ctrl+T: file picker, Alt+C: cd to dir
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi"
    fi

    # zoxide
    if [ "${TOOL_SELECTED[9]}" -eq 1 ]; then
        block="${block}

# zoxide — smart cd (learns your directories)
# z <query>: jump to dir, zi: interactive picker
if command -v zoxide &>/dev/null; then
    eval \"\$(zoxide init zsh)\"
fi"
    fi

    # bat
    if [ "${TOOL_SELECTED[12]}" -eq 1 ]; then
        block="${block}

# bat — modern cat with syntax highlighting
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi"
    fi

    # eza
    if [ "${TOOL_SELECTED[10]}" -eq 1 ]; then
        block="${block}

# eza — modern ls with git integration
if command -v eza &>/dev/null; then
    alias ls='eza'
    alias ll='eza -la --git --icons'
    alias lt='eza -T --level=2 --icons --git-ignore'
    alias la='eza -a'
fi"
    fi

    # lazygit
    if [ "${TOOL_SELECTED[11]}" -eq 1 ]; then
        block="${block}

# lazygit — git TUI
if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
fi"
    fi

    block="${block}
${MARKER_ZSHRC_END}"

    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would add/update block in $ZSHRC"
        result_add result_configured ".zshrc (dry-run)"
        return
    fi

    # Create .zshrc if missing
    if [ ! -f "$ZSHRC" ]; then
        touch "$ZSHRC"
        info "Created $ZSHRC"
    fi

    # Backup
    cp "$ZSHRC" "${ZSHRC}.powertools-backup"
    dim "  Backup: ${ZSHRC}.powertools-backup"

    # Remove existing block (if any)
    if grep -q "$MARKER_ZSHRC_BEGIN" "$ZSHRC"; then
        awk "/$MARKER_ZSHRC_BEGIN/{skip=1} /$MARKER_ZSHRC_END/{skip=0; next} !skip" "$ZSHRC" > "${ZSHRC}.tmp"
        mv "${ZSHRC}.tmp" "$ZSHRC"
        dim "  Removed previous powertools block from .zshrc"
    fi

    # Append new block
    echo "" >> "$ZSHRC"
    echo "$block" >> "$ZSHRC"
    result_add result_configured ".zshrc"
    info "Updated $ZSHRC with shell integrations"
}

# ── Configure Git ─────────────────────────────────────────────────────

configure_git() {
    # difftastic is index 6
    if [ "${TOOL_SELECTED[6]}" -ne 1 ]; then return; fi

    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would set git config diff.external = difft"
        result_add result_configured "git diff.external (dry-run)"
        return
    fi

    if command -v difft &>/dev/null; then
        local current
        current="$(git config --global diff.external 2>/dev/null || echo "")"
        if [ "$current" = "difft" ]; then
            dim "  git diff.external already set to difft"
        else
            git config --global diff.external difft
            result_add result_configured "git diff.external = difft"
            info "Set git diff.external = difft"
        fi
    fi
}

# ── Configure CLAUDE.md ───────────────────────────────────────────────

configure_claude_md() {
    # Check if any Claude-category tools are selected
    local has_claude_tools=false
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_SELECTED[$i]}" -eq 1 ] && [ "${TOOL_CAT[$i]}" = "claude" ]; then
            has_claude_tools=true
            break
        fi
    done

    if ! $has_claude_tools; then
        dim "  No Claude tools selected — skipping CLAUDE.md configuration"
        return
    fi

    # Build the table rows dynamically
    local table_rows=""

    # tree (0)
    if [ "${TOOL_SELECTED[0]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`tree -L 2 --dirsfirst\` | Project structure overview | Multiple ls/Glob calls |"
    fi
    # scc (5)
    if [ "${TOOL_SELECTED[5]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`scc --no-cocomo\` | Codebase size/language stats | \`find \\| wc -l\` |"
    fi
    # fd (3)
    if [ "${TOOL_SELECTED[3]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`fd -e py\` | Find files by name/ext/date | \`find . -name\` |"
    fi
    # ripgrep (4)
    if [ "${TOOL_SELECTED[4]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`rg\` (system) | Complex Bash pipelines with xargs/sort | Grep tool covers 80% |"
    fi
    # jq (7)
    if [ "${TOOL_SELECTED[7]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`jq\` | JSON parsing/filtering | Python one-liners |"
    fi
    # yq (1)
    if [ "${TOOL_SELECTED[1]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`yq\` | YAML/TOML parsing/filtering | Python one-liners |"
    fi
    # SC tool (index 2)
    if [ "${TOOL_SELECTED[2]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`shellcheck script.sh\` | Validate shell scripts after writing | Hope for the best |"
    fi
    # difftastic (6)
    if [ "${TOOL_SELECTED[6]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`difft\` | Syntax-aware git diff | \`git diff --no-ext-diff\` for line-based |"
    fi
    # imagemagick (13) — also useful for Claude
    if [ "${TOOL_SELECTED[13]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`magick\`/\`convert\` | Batch image resize/convert/watermark | — |"
    fi
    # htop (14) — informational
    if [ "${TOOL_SELECTED[14]}" -eq 1 ]; then
        table_rows="${table_rows}
| \`htop\` | Process monitoring (interactive, for user) | \`ps aux\` |"
    fi

    # Build rules dynamically
    local rules=""
    if [ "${TOOL_SELECTED[2]}" -eq 1 ]; then
        rules="${rules}
- Run \`shellcheck\` on every shell script you write or edit"
    fi
    if [ "${TOOL_SELECTED[0]}" -eq 1 ]; then
        rules="${rules}
- Use \`tree\` first when entering unfamiliar project"
    fi
    if [ "${TOOL_SELECTED[5]}" -eq 1 ]; then
        rules="${rules}
- Use \`scc\` when user asks about project scope/size"
    fi
    if [ "${TOOL_SELECTED[1]}" -eq 1 ] && [ "${TOOL_SELECTED[7]}" -eq 1 ]; then
        rules="${rules}
- Use \`yq\` for YAML, \`jq\` for JSON — never write Python for structured data parsing"
    elif [ "${TOOL_SELECTED[1]}" -eq 1 ]; then
        rules="${rules}
- Use \`yq\` for YAML/TOML parsing — never write Python for structured data parsing"
    elif [ "${TOOL_SELECTED[7]}" -eq 1 ]; then
        rules="${rules}
- Use \`jq\` for JSON parsing — never write Python for structured data parsing"
    fi
    if [ "${TOOL_SELECTED[6]}" -eq 1 ]; then
        rules="${rules}
- \`difft\` is configured as \`git diff.external\` globally"
    fi

    # Assemble the full block
    local block=""
    block="${MARKER_CLAUDE_BEGIN}
**CLI Toolbox** (installed via brew, USE proactively):

| Tool | Use for | Instead of |
|------|---------|------------|${table_rows}"

    if [ -n "$rules" ]; then
        block="${block}

**Rules:**${rules}"
    fi

    block="${block}
${MARKER_CLAUDE_END}"

    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would add/update block in $CLAUDE_MD"
        result_add result_configured "CLAUDE.md (dry-run)"
        return
    fi

    # Create dirs/file if needed
    mkdir -p "$CLAUDE_DIR"
    if [ ! -f "$CLAUDE_MD" ]; then
        echo "# CLAUDE.md" > "$CLAUDE_MD"
        echo "" >> "$CLAUDE_MD"
        info "Created $CLAUDE_MD"
    fi

    # Backup
    cp "$CLAUDE_MD" "${CLAUDE_MD}.powertools-backup"
    dim "  Backup: ${CLAUDE_MD}.powertools-backup"

    # Remove existing block (if any)
    if grep -q "$MARKER_CLAUDE_BEGIN" "$CLAUDE_MD"; then
        awk -v begin="$MARKER_CLAUDE_BEGIN" -v end="$MARKER_CLAUDE_END" \
            '$0 ~ begin {skip=1} $0 ~ end {skip=0; next} !skip' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp"
        mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
        dim "  Removed previous powertools block from CLAUDE.md"
    fi

    # Append new block
    echo "" >> "$CLAUDE_MD"
    echo "$block" >> "$CLAUDE_MD"
    result_add result_configured "CLAUDE.md"
    info "Updated $CLAUDE_MD with CLI Toolbox section"
}

# ── Summary ───────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo "  ──────────────────────────────────────────"
    echo -e "  ${BOLD}claude-code-powertools${RESET} — Summary"
    echo "  ──────────────────────────────────────────"

    result_print "Installed" "$GREEN" "+" "$result_installed"
    result_print "Already present" "$BLUE" "-" "$result_skipped"
    result_print "Configured" "$GREEN" "~" "$result_configured"
    result_print "Failed" "$RED" "!" "$result_failed"

    # Verification
    echo ""
    echo -e "  ${BOLD}Verification:${RESET}"
    for (( i=0; i<TOOL_COUNT; i++ )); do
        if [ "${TOOL_SELECTED[$i]}" -ne 1 ]; then continue; fi
        if command -v "${TOOL_CMD[$i]}" &>/dev/null; then
            echo -e "  ${GREEN}✓${RESET} ${TOOL_NAME[$i]}"
        else
            if $OPT_DRY_RUN; then
                echo -e "  ${DIM}~ ${TOOL_NAME[$i]} (dry-run)${RESET}"
            else
                echo -e "  ${RED}✗${RESET} ${TOOL_NAME[$i]}"
            fi
        fi
    done

    echo ""
    if [ -n "$result_configured" ]; then
        dim "  Restart your shell to activate integrations: exec zsh"
    fi
    dim "  Uninstall: bash uninstall.sh (from repo) or:"
    dim "  curl -sL https://raw.githubusercontent.com/dkh-ai/claude-code-powertools/main/uninstall.sh | bash"
    echo ""
}

# ── Warn About Duplicates ─────────────────────────────────────────────

warn_duplicates() {
    if [ ! -f "$ZSHRC" ]; then return; fi

    # Check for common manual integrations outside our markers
    local found_dups=false

    # fzf (index 8)
    if [ "${TOOL_SELECTED[8]}" -eq 1 ] && grep -q "fzf --zsh" "$ZSHRC" 2>/dev/null; then
        if ! awk "/$MARKER_ZSHRC_BEGIN/,/$MARKER_ZSHRC_END/" "$ZSHRC" | grep -q "fzf --zsh" 2>/dev/null; then
            if ! $found_dups; then
                echo ""
                warn "Potential duplicate integrations detected in .zshrc:"
                found_dups=true
            fi
            echo "    fzf shell integration"
        fi
    fi

    # zoxide (index 9)
    if [ "${TOOL_SELECTED[9]}" -eq 1 ] && grep -q "zoxide init" "$ZSHRC" 2>/dev/null; then
        if ! awk "/$MARKER_ZSHRC_BEGIN/,/$MARKER_ZSHRC_END/" "$ZSHRC" | grep -q "zoxide init" 2>/dev/null; then
            if ! $found_dups; then
                echo ""
                warn "Potential duplicate integrations detected in .zshrc:"
                found_dups=true
            fi
            echo "    zoxide init"
        fi
    fi

    if $found_dups; then
        echo "  You may want to remove the manual entries to avoid double-loading."
    fi
}

# ── Main ──────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    if $OPT_HELP; then
        show_help
        exit 0
    fi

    echo ""
    echo -e "  ${BOLD}claude-code-powertools${RESET} v${VERSION}"
    echo "  CLI tools for Claude Code and your terminal"
    echo "  ──────────────────────────────────────────"
    echo ""

    if $OPT_DRY_RUN; then
        warn "Dry-run mode — no changes will be made"
        echo ""
    fi

    detect_tty
    preflight

    # Apply preset if given
    if [ -n "$OPT_PRESET" ]; then
        apply_preset "$OPT_PRESET"
        echo ""
        info "Preset '$OPT_PRESET': $(count_selected) tools selected"
    fi

    # Interactive menu (skipped if --yes)
    interactive_menu

    local selected
    selected="$(count_selected)"
    if [ "$selected" -eq 0 ]; then
        warn "No tools selected. Nothing to do."
        exit 0
    fi

    echo ""
    info "$selected tool(s) selected"

    # Install
    install_tools

    # Configure
    echo ""
    echo -e "  ${BOLD}Configuring...${RESET}"
    configure_zshrc
    configure_git
    configure_claude_md
    warn_duplicates

    # Summary
    print_summary
}

main "$@"
