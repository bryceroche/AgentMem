#!/bin/bash
# bdx-today - Daily accomplishment summary
#
# Shows what you closed today, context added, and streak.
# Great for standups and end-of-day recaps.
#
# Usage: bdx-today [--yesterday]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DB=".beads/beads.db"
CONTEXT_FILE=".beads/context.json"
OUTCOMES_FILE=".beads/outcomes.jsonl"

# Default to today
DATE_FILTER="date('now')"
DATE_DISPLAY=$(date +"%A, %B %d, %Y")
DAY_LABEL="TODAY"

show_help() {
    echo "bdx-today - Daily accomplishment summary"
    echo ""
    echo "Usage: bdx-today [options]"
    echo ""
    echo "Options:"
    echo "  --yesterday    Show yesterday's accomplishments"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Shows closed issues, added context, and success streak."
    exit 0
}

case "$1" in
    -h|--help) show_help ;;
    --yesterday)
        DATE_FILTER="date('now', '-1 day')"
        DATE_DISPLAY=$(date -v-1d +"%A, %B %d, %Y" 2>/dev/null || date -d "yesterday" +"%A, %B %d, %Y")
        DAY_LABEL="YESTERDAY"
        ;;
esac

echo ""
echo -e "${BOLD}📅 ${DAY_LABEL}: ${DATE_DISPLAY}${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Closed issues today
if [ -f "$DB" ]; then
    CLOSED_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM issues WHERE status='closed' AND date(closed_at)=$DATE_FILTER" 2>/dev/null || echo "0")

    if [ "$CLOSED_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ CLOSED${NC} ${DIM}($CLOSED_COUNT)${NC}"
        sqlite3 -separator '|' "$DB" "
            SELECT id, title FROM issues
            WHERE status='closed' AND date(closed_at)=$DATE_FILTER
            ORDER BY closed_at DESC
            LIMIT 10
        " 2>/dev/null | while IFS='|' read -r id title; do
            if [ ${#title} -gt 50 ]; then
                title="${title:0:47}..."
            fi
            echo -e "  ${BLUE}${id}${NC}  ${title}"
        done

        if [ "$CLOSED_COUNT" -gt 10 ]; then
            echo -e "  ${DIM}... and $((CLOSED_COUNT - 10)) more${NC}"
        fi
        echo ""
    else
        echo -e "${DIM}No issues closed ${DAY_LABEL,,}.${NC}"
        echo ""
    fi
fi

# Context added today
if [ -f "$CONTEXT_FILE" ]; then
    TODAY_DATE=$(date +%Y-%m-%d)
    [ "$DAY_LABEL" = "YESTERDAY" ] && TODAY_DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

    CONTEXT_ENTRIES=$(python3 << EOF
import json
from datetime import datetime

with open("$CONTEXT_FILE") as f:
    ctx = json.load(f)

count = 0
entries = []

for issue_id, data in ctx.items():
    if isinstance(data, dict):
        for note in data.get('notes', []):
            if note.get('date', '').startswith('$TODAY_DATE'):
                entries.append((issue_id, note.get('text', '')[:40]))
                count += 1
        for dec in data.get('decisions', []):
            if dec.get('date', '').startswith('$TODAY_DATE'):
                entries.append((issue_id, "⚖️ " + dec.get('what', '')[:35]))
                count += 1
        for find in data.get('findings', []):
            if find.get('date', '').startswith('$TODAY_DATE'):
                entries.append((issue_id, "🔍 " + find.get('text', '')[:35]))
                count += 1

if entries:
    print(f"COUNT:{count}")
    for issue_id, text in entries[:5]:
        print(f"  \033[0;34m{issue_id}\033[0m  {text}...")
    if len(entries) > 5:
        print(f"  \033[2m... and {len(entries) - 5} more\033[0m")
EOF
2>/dev/null)

    if [ -n "$CONTEXT_ENTRIES" ]; then
        CONTEXT_COUNT=$(echo "$CONTEXT_ENTRIES" | grep "^COUNT:" | cut -d: -f2)
        echo -e "${CYAN}📝 CONTEXT ADDED${NC} ${DIM}($CONTEXT_COUNT)${NC}"
        echo "$CONTEXT_ENTRIES" | grep -v "^COUNT:"
        echo ""
    fi
fi

# Outcomes today
if [ -f "$OUTCOMES_FILE" ]; then
    TODAY_DATE=$(date +%Y-%m-%d)
    [ "$DAY_LABEL" = "YESTERDAY" ] && TODAY_DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

    OUTCOMES=$(python3 << EOF
import json

outcomes = []
with open("$OUTCOMES_FILE") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

# Filter to today
today_outcomes = [o for o in outcomes if o.get('closed', '').startswith('$TODAY_DATE')]
successes = sum(1 for o in today_outcomes if o.get('success'))
failures = len(today_outcomes) - successes

if today_outcomes:
    print(f"OUTCOMES:{len(today_outcomes)}:{successes}:{failures}")
EOF
2>/dev/null)

    if [ -n "$OUTCOMES" ]; then
        TOTAL=$(echo "$OUTCOMES" | cut -d: -f2)
        SUCCESSES=$(echo "$OUTCOMES" | cut -d: -f3)
        FAILURES=$(echo "$OUTCOMES" | cut -d: -f4)

        echo -e "${MAGENTA}📊 OUTCOMES${NC} ${DIM}($TOTAL)${NC}"
        echo -e "  ${GREEN}✅ $SUCCESSES successful${NC}  ${RED}❌ $FAILURES failed${NC}"
        echo ""
    fi
fi

# Success streak
if [ -f "$OUTCOMES_FILE" ]; then
    STREAK=$(python3 << EOF
import json

outcomes = []
with open("$OUTCOMES_FILE") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

# Sort by date descending
outcomes.sort(key=lambda x: x.get('closed', ''), reverse=True)

streak = 0
for o in outcomes:
    if o.get('success'):
        streak += 1
    else:
        break

if streak >= 5:
    print(f"🔥 SUCCESS STREAK: {streak} in a row!")
elif streak > 0:
    print(f"✨ Streak: {streak} successful")
EOF
2>/dev/null)

    if [ -n "$STREAK" ]; then
        echo -e "${YELLOW}${STREAK}${NC}"
        echo ""
    fi
fi

# Footer
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${DIM}Run 'bdx-today --yesterday' to see previous day${NC}"
echo ""
