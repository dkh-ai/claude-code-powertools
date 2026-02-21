#!/usr/bin/env bash
# claude-code-powertools — Uninstaller
# Removes all configuration added by the installer.
# Optionally uninstalls tools via Homebrew.
#
# Usage:
#   bash uninstall.sh [--yes]
#   curl -sL https://raw.githubusercontent.com/dkh-ai/claude-code-powertools/main/uninstall.sh | bash

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

MARKER_ZSHRC_BEGIN="# >>> claude-code-powertools >>>"
MARKER_ZSHRC_END="# <<< claude-code-powertools <<<"
MARKER_CLAUDE_BEGIN="<!-- claude-code-powertools:begin -->"
MARKER_CLAUDE_END="<!-- claude-code-powertools:end -->"

ZSHRC="$HOME/.zshrc"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# ── Colors ─────────────────────────────────────────────────────────────

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}!${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*"; }
dim()   { echo -e "${DIM}$*${RESET}"; }

# ── CLI Arguments ──────────────────────────────────────────────────────

OPT_YES=false

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)  OPT_YES=true ;;
        --help|-h)
            echo "Usage: bash uninstall.sh [--yes]"
            echo "  --yes   Skip confirmations"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# TTY detection
if [ ! -t 0 ]; then
    OPT_YES=true
fi

confirm() {
    if $OPT_YES; then return 0; fi
    local prompt="$1"
    echo -en "${YELLOW}${prompt} [y/N]:${RESET} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ── Tool List ──────────────────────────────────────────────────────────

BREW_PACKAGES="tree yq shellcheck fd ripgrep scc difftastic jq fzf zoxide eza lazygit bat imagemagick htop"

# ── Main ───────────────────────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}claude-code-powertools${RESET} — Uninstaller"
echo "  ──────────────────────────────────────────"
echo ""

removed=0

# ── 1. Remove .zshrc block ────────────────────────────────────────────

if [ -f "$ZSHRC" ] && grep -q "$MARKER_ZSHRC_BEGIN" "$ZSHRC"; then
    awk "/$MARKER_ZSHRC_BEGIN/{skip=1} /$MARKER_ZSHRC_END/{skip=0; next} !skip" "$ZSHRC" > "${ZSHRC}.tmp"
    mv "${ZSHRC}.tmp" "$ZSHRC"
    info "Removed powertools block from $ZSHRC"
    removed=$((removed + 1))
else
    dim "  No powertools block found in .zshrc"
fi

# ── 2. Remove CLAUDE.md block ─────────────────────────────────────────

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER_CLAUDE_BEGIN" "$CLAUDE_MD"; then
    awk -v begin="$MARKER_CLAUDE_BEGIN" -v end="$MARKER_CLAUDE_END" \
        '$0 ~ begin {skip=1} $0 ~ end {skip=0; next} !skip' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp"
    mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
    info "Removed powertools block from $CLAUDE_MD"
    removed=$((removed + 1))
else
    dim "  No powertools block found in CLAUDE.md"
fi

# ── 3. Revert git config ──────────────────────────────────────────────

current_diff_ext="$(git config --global diff.external 2>/dev/null || echo "")"
if [ "$current_diff_ext" = "difft" ]; then
    git config --global --unset diff.external
    info "Reverted git config diff.external"
    removed=$((removed + 1))
else
    dim "  git diff.external not set to difft — skipping"
fi

# ── 4. Offer to uninstall brew packages ───────────────────────────────

echo ""
installed_packages=""
installed_count=0

for pkg in $BREW_PACKAGES; do
    if brew list "$pkg" &>/dev/null; then
        installed_packages="${installed_packages} ${pkg}"
        installed_count=$((installed_count + 1))
    fi
done

if [ "$installed_count" -gt 0 ]; then
    warn "Found $installed_count tool(s) installed via Homebrew:${installed_packages}"
    echo ""
    if confirm "Uninstall these packages with brew?"; then
        for pkg in $installed_packages; do
            if confirm "  Uninstall $pkg?"; then
                if brew uninstall "$pkg" 2>/dev/null; then
                    info "Uninstalled $pkg"
                else
                    warn "Failed to uninstall $pkg"
                fi
                removed=$((removed + 1))
            else
                dim "  Kept $pkg"
            fi
        done
    else
        dim "  Keeping all brew packages"
    fi
else
    dim "  No powertools brew packages found"
fi

# ── 5. Offer to restore backups ───────────────────────────────────────

echo ""
if [ -f "${ZSHRC}.powertools-backup" ] || [ -f "${CLAUDE_MD}.powertools-backup" ]; then
    warn "Backup files found:"
    [ -f "${ZSHRC}.powertools-backup" ] && echo "    ${ZSHRC}.powertools-backup"
    [ -f "${CLAUDE_MD}.powertools-backup" ] && echo "    ${CLAUDE_MD}.powertools-backup"
    echo ""
    if confirm "Restore backups? (This replaces current files with pre-install versions)"; then
        if [ -f "${ZSHRC}.powertools-backup" ]; then
            cp "${ZSHRC}.powertools-backup" "$ZSHRC"
            info "Restored $ZSHRC from backup"
        fi
        if [ -f "${CLAUDE_MD}.powertools-backup" ]; then
            cp "${CLAUDE_MD}.powertools-backup" "$CLAUDE_MD"
            info "Restored $CLAUDE_MD from backup"
        fi
    else
        dim "  Backups kept (you can delete them manually)"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────

echo ""
echo "  ──────────────────────────────────────────"
if [ "$removed" -gt 0 ]; then
    info "Uninstall complete ($removed actions performed)"
    dim "  Restart your shell to apply changes: exec zsh"
else
    info "Nothing to remove — already clean"
fi
echo ""
