#!/bin/bash
# bdx-usage - View command usage statistics
# Shows which commands are actually being used

set -e

USAGE_FILE=".beads/usage.jsonl"

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

show_help() {
    echo "bdx-usage - View command usage statistics"
    echo ""
    echo "Usage:"
    echo "  bdx-usage              Show usage summary"
    echo "  bdx-usage recent [n]   Show n most recent commands"
    echo "  bdx-usage clear        Clear usage history"
    echo ""
    exit 0
}

case "$1" in
    -h|--help) show_help ;;
esac

if [[ ! -f "$USAGE_FILE" ]]; then
    echo "No usage data yet. Run some bdx-* or bd commands first."
    exit 0
fi

show_summary() {
    echo -e "${CYAN}═══ COMMAND USAGE STATISTICS ═══${NC}"
    echo ""

    # Count by command
    echo -e "${YELLOW}By Command:${NC}"
    jq -r '.cmd' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | while read count cmd; do
        bar=$(printf '█%.0s' $(seq 1 $((count / 2 + 1))))
        printf "  %-20s %s %d\n" "$cmd" "$bar" "$count"
    done

    echo ""
    echo -e "${YELLOW}By Subcommand:${NC}"
    jq -r 'select(.subcmd != null and .subcmd != "") | "\(.cmd) \(.subcmd)"' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | while read count cmd subcmd; do
        printf "  %-25s %d\n" "$cmd $subcmd" "$count"
    done

    echo ""
    total=$(wc -l < "$USAGE_FILE" | tr -d ' ')
    first=$(head -1 "$USAGE_FILE" | jq -r '.ts' 2>/dev/null | cut -c1-10)
    last=$(tail -1 "$USAGE_FILE" | jq -r '.ts' 2>/dev/null | cut -c1-10)
    echo -e "${GREEN}Total: $total commands tracked ($first to $last)${NC}"
    echo ""
}

show_recent() {
    local n=${1:-10}
    echo -e "${CYAN}═══ RECENT COMMANDS ═══${NC}"
    echo ""
    tail -"$n" "$USAGE_FILE" | jq -r '"  \(.ts[0:19]) \(.cmd) \(.subcmd // "") \(.args // "")"' 2>/dev/null
    echo ""
}

clear_usage() {
    read -p "Clear all usage history? [y/N] " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -f "$USAGE_FILE"
        echo "Usage history cleared."
    fi
}

case "$1" in
    recent)
        show_recent "${2:-10}"
        ;;
    clear)
        clear_usage
        ;;
    *)
        show_summary
        ;;
esac
