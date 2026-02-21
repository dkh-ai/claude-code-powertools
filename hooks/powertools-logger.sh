#!/usr/bin/env bash
# claude-code-powertools — PostToolUse hook
# Logs powertools CLI invocations to ~/.claude/powertools-usage.jsonl
#
# Called by Claude Code after each tool use. Receives JSON on stdin.
# Non-blocking: always exits 0.

# Require jq for JSON parsing
command -v jq >/dev/null 2>&1 || exit 0

# Read stdin JSON (Claude Code PostToolUse payload)
input="$(cat)"

# Only process Bash tool calls
tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[ "$tool_name" = "Bash" ] || exit 0

# Extract command and session info
cmd="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[ -n "$cmd" ] || exit 0

cwd="$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)"
session_id="$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)"

# Extract first word (binary name) from command
# Handle: leading whitespace, env vars, sudo, path prefixes
binary="$(echo "$cmd" | sed 's/^[[:space:]]*//' | awk '{print $1}')"
# Strip path prefix (e.g. /usr/bin/tree → tree)
binary="$(basename "$binary")"

# Match against known powertools
case "$binary" in
    tree|yq|shellcheck|fd|rg|scc|difft|jq|fzf|zoxide|eza|lazygit|bat|magick|convert|htop)
        ;;
    *)
        exit 0
        ;;
esac

# Derive project name from cwd
project=""
if [ -n "$cwd" ]; then
    project="$(basename "$cwd")"
fi

# Timestamp in ISO 8601 UTC
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Write JSONL entry
log_file="$HOME/.claude/powertools-usage.jsonl"
jq -cn \
    --arg ts "$ts" \
    --arg tool "$binary" \
    --arg cmd "$cmd" \
    --arg project "$project" \
    --arg session "$session_id" \
    '{ts: $ts, tool: $tool, cmd: $cmd, project: $project, session: $session}' \
    >> "$log_file" 2>/dev/null

exit 0
