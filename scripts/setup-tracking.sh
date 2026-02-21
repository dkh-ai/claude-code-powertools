#!/usr/bin/env bash
# claude-code-powertools — Usage Tracking Setup
# Installs the PostToolUse hook for tracking powertools usage.
#
# Usage:
#   bash scripts/setup-tracking.sh [--yes] [--dry-run]

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

HOOK_SRC="$(cd "$(dirname "$0")/.." && pwd)/hooks/powertools-logger.sh"
HOOK_DST="$HOME/.claude/hooks/powertools-logger.sh"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="bash ~/.claude/hooks/powertools-logger.sh"

# ── Colors ─────────────────────────────────────────────────────────────

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}!${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*" >&2; }
dim()   { echo -e "${DIM}$*${RESET}"; }

# ── CLI Arguments ──────────────────────────────────────────────────────

OPT_YES=false
OPT_DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)     OPT_YES=true ;;
        --dry-run|-n) OPT_DRY_RUN=true ;;
        --help|-h)
            echo "Usage: bash scripts/setup-tracking.sh [--yes] [--dry-run]"
            echo "  --yes       Skip confirmations"
            echo "  --dry-run   Preview changes without modifying anything"
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

# ── Preflight ──────────────────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}claude-code-powertools${RESET} — Usage Tracking Setup"
echo "  ──────────────────────────────────────────"
echo ""

# Check jq
if ! command -v jq >/dev/null 2>&1; then
    error "jq is required but not installed. Run: brew install jq"
    exit 1
fi

# Check hook source exists
if [ ! -f "$HOOK_SRC" ]; then
    error "Hook source not found: $HOOK_SRC"
    error "Run this script from the claude-code-powertools directory."
    exit 1
fi

# ── 1. Copy hook script ───────────────────────────────────────────────

echo -e "  ${BOLD}Step 1:${RESET} Copy hook script"

if [ -f "$HOOK_DST" ] && diff -q "$HOOK_SRC" "$HOOK_DST" >/dev/null 2>&1; then
    dim "  Hook already installed and up to date"
else
    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would copy $HOOK_SRC → $HOOK_DST"
    else
        mkdir -p "$(dirname "$HOOK_DST")"
        cp "$HOOK_SRC" "$HOOK_DST"
        chmod +x "$HOOK_DST"
        info "Copied hook to $HOOK_DST"
    fi
fi

# ── 2. Update settings.json ──────────────────────────────────────────

echo ""
echo -e "  ${BOLD}Step 2:${RESET} Configure PostToolUse hook in settings.json"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS" ]; then
    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would create $SETTINGS with hook config"
    else
        mkdir -p "$(dirname "$SETTINGS")"
        echo '{}' > "$SETTINGS"
        dim "  Created $SETTINGS"
    fi
fi

# Check if hook is already configured
hook_exists=false
if [ -f "$SETTINGS" ]; then
    # Check if our specific hook command already exists in PostToolUse
    if jq -e '.hooks.PostToolUse[]? | select(.matcher == "Bash") | .hooks[]? | select(.command == "'"$HOOK_CMD"'")' "$SETTINGS" >/dev/null 2>&1; then
        hook_exists=true
    fi
fi

if $hook_exists; then
    dim "  Hook already configured in settings.json"
else
    if $OPT_DRY_RUN; then
        dim "  [dry-run] Would add PostToolUse hook to $SETTINGS"
        echo ""
        dim "  Hook config preview:"
        echo '  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "'"$HOOK_CMD"'"
      }
    ]
  }'
    else
        if ! confirm "Add PostToolUse hook to settings.json?"; then
            warn "Skipped settings.json update"
            echo ""
            echo -e "  ${BOLD}Setup incomplete.${RESET} Hook script copied but not activated."
            echo "  To activate manually, add to $SETTINGS:"
            echo '  "hooks": { "PostToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "'"$HOOK_CMD"'" }] }] }'
            exit 0
        fi

        # Build the new hook entry
        new_hook='{"matcher":"Bash","hooks":[{"type":"command","command":"'"$HOOK_CMD"'"}]}'

        # Merge into settings.json
        if jq -e '.hooks.PostToolUse' "$SETTINGS" >/dev/null 2>&1; then
            # PostToolUse array exists — append our entry
            jq --argjson entry "$new_hook" '.hooks.PostToolUse += [$entry]' "$SETTINGS" > "${SETTINGS}.tmp"
        elif jq -e '.hooks' "$SETTINGS" >/dev/null 2>&1; then
            # hooks object exists but no PostToolUse — add it
            jq --argjson entry "$new_hook" '.hooks.PostToolUse = [$entry]' "$SETTINGS" > "${SETTINGS}.tmp"
        else
            # No hooks at all — create the whole structure
            jq --argjson entry "$new_hook" '.hooks = {"PostToolUse": [$entry]}' "$SETTINGS" > "${SETTINGS}.tmp"
        fi

        mv "${SETTINGS}.tmp" "$SETTINGS"
        info "Added PostToolUse hook to settings.json"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────

echo ""
echo "  ──────────────────────────────────────────"
if $OPT_DRY_RUN; then
    info "Dry run complete — no changes made"
else
    info "Usage tracking enabled"
    dim "  Log file: ~/.claude/powertools-usage.jsonl"
    dim "  View report: bash scripts/usage-report.sh"
fi
echo ""
