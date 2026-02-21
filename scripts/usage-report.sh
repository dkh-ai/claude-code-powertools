#!/usr/bin/env bash
# claude-code-powertools — Usage Report
# Analyzes powertools usage log and displays statistics.
#
# Usage:
#   bash scripts/usage-report.sh [--format text|markdown|json] [--days N]

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

LOG_FILE="$HOME/.claude/powertools-usage.jsonl"

# ── Colors ─────────────────────────────────────────────────────────────

GREEN='\033[32m'
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
RESET='\033[0m'

# ── CLI Arguments ──────────────────────────────────────────────────────

FORMAT="text"
DAYS=30

while [ $# -gt 0 ]; do
    case "$1" in
        --format|-f)
            shift
            case "${1:-}" in
                text|markdown|json) FORMAT="$1" ;;
                *) echo "Error: --format must be text, markdown, or json" >&2; exit 1 ;;
            esac
            ;;
        --days|-d)
            shift
            DAYS="${1:-30}"
            ;;
        --help|-h)
            echo "Usage: bash scripts/usage-report.sh [--format text|markdown|json] [--days N]"
            echo ""
            echo "Options:"
            echo "  --format, -f   Output format: text (default), markdown, json"
            echo "  --days, -d     Number of days to include (default: 30)"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ── Preflight ──────────────────────────────────────────────────────────

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required. Run: brew install jq" >&2
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    if [ "$FORMAT" = "json" ]; then
        echo '{"total":0,"tools":{},"projects":{},"daily":{},"recent":[]}'
    elif [ "$FORMAT" = "markdown" ]; then
        echo "## Powertools Usage Report"
        echo ""
        echo "No usage data found. Log file: \`~/.claude/powertools-usage.jsonl\`"
    else
        echo "No usage data found."
        echo "Log file: ~/.claude/powertools-usage.jsonl"
    fi
    exit 0
fi

# ── Date filter ────────────────────────────────────────────────────────

# Calculate cutoff date (N days ago) in ISO format
if date -v -1d >/dev/null 2>&1; then
    # macOS date
    cutoff_date="$(date -u -v "-${DAYS}d" '+%Y-%m-%dT00:00:00Z')"
else
    # GNU date
    cutoff_date="$(date -u -d "${DAYS} days ago" '+%Y-%m-%dT00:00:00Z')"
fi

# ── Gather data ────────────────────────────────────────────────────────

# Filter entries within date range
filtered="$(jq -c --arg cutoff "$cutoff_date" 'select(.ts >= $cutoff)' "$LOG_FILE" 2>/dev/null)" || filtered=""

if [ -z "$filtered" ]; then
    if [ "$FORMAT" = "json" ]; then
        echo '{"total":0,"days":'"$DAYS"',"tools":{},"projects":{},"daily":{},"recent":[]}'
    elif [ "$FORMAT" = "markdown" ]; then
        echo "## Powertools Usage Report"
        echo ""
        echo "No usage data in the last $DAYS days."
    else
        echo "No usage data in the last $DAYS days."
    fi
    exit 0
fi

total_count="$(echo "$filtered" | wc -l | tr -d ' ')"

# By tool (sorted by count, descending)
by_tool="$(echo "$filtered" | jq -r '.tool' | sort | uniq -c | sort -rn)"

# By project (sorted by count, descending)
by_project="$(echo "$filtered" | jq -r '.project // "unknown"' | sort | uniq -c | sort -rn)"

# By day (last 7 days)
by_day="$(echo "$filtered" | jq -r '.ts[:10]' | sort | uniq -c | sort -r | head -7)"

# Recent 10 entries
recent="$(echo "$filtered" | tail -10 | jq -c '.' 2>/dev/null)" || recent=""

# ── Output: JSON ───────────────────────────────────────────────────────

if [ "$FORMAT" = "json" ]; then
    tools_json="$(echo "$by_tool" | awk '{print "\"" $2 "\": " $1}' | paste -sd',' - )"
    projects_json="$(echo "$by_project" | awk '{print "\"" $2 "\": " $1}' | paste -sd',' - )"
    daily_json="$(echo "$by_day" | awk '{print "\"" $2 "\": " $1}' | paste -sd',' - )"
    recent_json="$(echo "$recent" | jq -s '.' 2>/dev/null || echo '[]')"

    jq -n \
        --argjson total "$total_count" \
        --argjson days "$DAYS" \
        --argjson tools "{${tools_json:-}}" \
        --argjson projects "{${projects_json:-}}" \
        --argjson daily "{${daily_json:-}}" \
        --argjson recent "$recent_json" \
        '{total: $total, days: $days, tools: $tools, projects: $projects, daily: $daily, recent: $recent}'
    exit 0
fi

# ── Output: Markdown ──────────────────────────────────────────────────

if [ "$FORMAT" = "markdown" ]; then
    echo "## Powertools Usage Report"
    echo ""
    echo "**Period:** last $DAYS days | **Total calls:** $total_count"
    echo ""

    echo "### By Tool"
    echo ""
    echo "| Tool | Calls |"
    echo "|------|-------|"
    echo "$by_tool" | awk '{printf "| %s | %s |\n", $2, $1}'
    echo ""

    echo "### By Project"
    echo ""
    echo "| Project | Calls |"
    echo "|---------|-------|"
    echo "$by_project" | awk '{printf "| %s | %s |\n", $2, $1}'
    echo ""

    echo "### Last 7 Days"
    echo ""
    echo "| Date | Calls |"
    echo "|------|-------|"
    echo "$by_day" | awk '{printf "| %s | %s |\n", $2, $1}'
    echo ""

    if [ -n "$recent" ]; then
        echo "### Recent Calls"
        echo ""
        echo "| Time | Tool | Command | Project |"
        echo "|------|------|---------|---------|"
        echo "$recent" | jq -r '"| \(.ts[:16]) | \(.tool) | `\(.cmd[:50])` | \(.project) |"' 2>/dev/null
    fi

    exit 0
fi

# ── Output: Text (default) ────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}Powertools Usage Report${RESET}"
echo "  ──────────────────────────────────────────"
echo ""
echo -e "  Period: last ${BOLD}$DAYS${RESET} days"
echo -e "  Total calls: ${BOLD}${total_count}${RESET}"
echo ""

echo -e "  ${BOLD}By Tool${RESET}"
echo "$by_tool" | while read -r count tool; do
    bar_len=$((count * 30 / total_count))
    [ "$bar_len" -lt 1 ] && bar_len=1
    bar="$(printf '%*s' "$bar_len" '' | tr ' ' '█')"
    printf "  ${CYAN}%-12s${RESET} %4s  ${GREEN}%s${RESET}\n" "$tool" "$count" "$bar"
done
echo ""

echo -e "  ${BOLD}By Project${RESET}"
echo "$by_project" | while read -r count project; do
    printf "  %-30s %4s\n" "$project" "$count"
done
echo ""

echo -e "  ${BOLD}Last 7 Days${RESET}"
echo "$by_day" | while read -r count day; do
    bar_len=$((count * 20 / total_count))
    [ "$bar_len" -lt 1 ] && bar_len=1
    bar="$(printf '%*s' "$bar_len" '' | tr ' ' '▓')"
    printf "  ${DIM}%-12s${RESET} %4s  %s\n" "$day" "$count" "$bar"
done
echo ""

if [ -n "$recent" ]; then
    echo -e "  ${BOLD}Recent Calls${RESET}"
    echo "$recent" | jq -r '"  \(.ts[:16])  \(.tool)  \(.cmd[:60])  (\(.project))"' 2>/dev/null | while read -r line; do
        echo -e "  ${DIM}${line}${RESET}"
    done
    echo ""
fi

echo "  ──────────────────────────────────────────"
echo -e "  ${DIM}Log: ~/.claude/powertools-usage.jsonl${RESET}"
echo ""
