#!/bin/bash
# am-prime - Enhanced session startup
# Usage: am-prime
#
# Loads everything needed to resume work:
# - Journal (preferences, decisions, session notes)
# - Recent context entries
# - Open/in-progress issues
# - Recent changes

show_help() {
    echo "am-prime - Load session context for AI coding agents"
    echo ""
    echo "Usage: am-prime [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Description:"
    echo "  Loads everything needed to resume work after a session break:"
    echo "  - User preferences from .beads/JOURNAL.md"
    echo "  - Recent context entries (findings, decisions, notes)"
    echo "  - Outcome statistics (success rates, patterns)"
    echo "  - Open and in-progress issues"
    echo "  - Recently modified files"
    echo ""
    echo "Run this at the start of every coding session."
    exit 0
}

# Handle --help
case "$1" in
    -h|--help) show_help ;;
esac

JOURNAL=".beads/JOURNAL.md"
CONTEXT=".beads/context.json"
DB=".beads/beads.db"
SCRIPTS_DIR="$(dirname "$0")"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│                    AGENTMEM SESSION START                   │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "$(date '+%Y-%m-%d %H:%M') - Starting session..."
echo ""

# ═══════════════════════════════════════════════════════════════════════
# SECTION 1: JOURNAL - Preferences & Decisions
# ═══════════════════════════════════════════════════════════════════════
echo -e "${CYAN}═══ JOURNAL (Preferences & Decisions) ═══${NC}"
echo ""

if [ -f "$JOURNAL" ]; then
    # Show User Preferences section
    echo -e "${YELLOW}User Preferences:${NC}"
    sed -n '/^## User Preferences/,/^## /p' "$JOURNAL" | head -15 | tail -n +2 | grep -v "^## "
    echo ""

    # Show Key Decisions section (last 5)
    echo -e "${YELLOW}Key Decisions (recent):${NC}"
    sed -n '/^## Key Decisions/,/^## /p' "$JOURNAL" | head -20 | tail -n +2 | grep -v "^## " | tail -10
    echo ""
else
    echo "  (No journal found - create .beads/JOURNAL.md)"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════
# SECTION 2: RECENT CONTEXT - Rich Context (Findings, Decisions, Notes)
# ═══════════════════════════════════════════════════════════════════════
echo -e "${CYAN}═══ RECENT CONTEXT (Decision Rationale) ═══${NC}"
echo ""

if [ -f "$CONTEXT" ] && command -v python3 &> /dev/null; then
    python3 -c "
import json
from datetime import datetime, timedelta

with open('$CONTEXT') as f:
    data = json.load(f)

# Get entries from last 7 days
cutoff = datetime.now() - timedelta(days=7)
recent = []

for issue_id, ctx in data.items():
    # Handle both legacy (list) and new (dict) formats
    if isinstance(ctx, list):
        # Legacy format: list of {date, text}
        for e in ctx:
            try:
                date = datetime.strptime(e['date'], '%Y-%m-%d %H:%M')
                if date > cutoff:
                    recent.append((date, issue_id, e['text'][:60], 'note'))
            except:
                pass
    elif isinstance(ctx, dict):
        # New rich format
        for e in ctx.get('notes', []):
            try:
                date = datetime.strptime(e['date'], '%Y-%m-%d %H:%M')
                if date > cutoff:
                    recent.append((date, issue_id, e['text'][:60], 'note'))
            except:
                pass
        for e in ctx.get('findings', []):
            try:
                date = datetime.strptime(e['date'], '%Y-%m-%d %H:%M')
                if date > cutoff:
                    recent.append((date, issue_id, e['text'][:55], 'finding'))
            except:
                pass
        for e in ctx.get('decisions', []):
            try:
                date = datetime.strptime(e['date'], '%Y-%m-%d %H:%M')
                if date > cutoff:
                    recent.append((date, issue_id, e['what'][:55], 'decision'))
            except:
                pass

# Sort by date, show latest 5
recent.sort(reverse=True)
for date, issue_id, text, entry_type in recent[:5]:
    prefix = {'note': '', 'finding': '💡 ', 'decision': '⚖️ '}[entry_type]
    print(f'  [{issue_id}] {prefix}{text}...')

if not recent:
    print('  (No recent context entries)')
" 2>/dev/null
else
    echo "  (No context file or python3 not available)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# SECTION 3: OUTCOME INSIGHTS - Learning from completed work
# ═══════════════════════════════════════════════════════════════════════
OUTCOMES=".beads/outcomes.jsonl"
if [ -f "$OUTCOMES" ] && [ -s "$OUTCOMES" ] && command -v python3 &> /dev/null; then
    echo -e "${CYAN}═══ OUTCOME INSIGHTS (Emergent Learning) ═══${NC}"
    echo ""
    python3 -c "
import json
from datetime import datetime, timedelta

outcomes = []
with open('$OUTCOMES', 'r') as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if outcomes:
    # Overall stats
    total = len(outcomes)
    successes = sum(1 for o in outcomes if o.get('success'))
    durations = [o['duration_min'] for o in outcomes if o.get('duration_min')]
    avg_duration = int(sum(durations) / len(durations)) if durations else 0

    print(f'  📊 {successes}/{total} successful ({100*successes//total}%) | Avg duration: {avg_duration} min')

    # Show 3 most recent
    outcomes.sort(key=lambda x: x.get('closed', ''), reverse=True)
    print()
    print('  Recent outcomes:')
    for o in outcomes[:3]:
        icon = '✅' if o.get('success') else '❌'
        issue = o.get('issue', '?')
        approach = o.get('approach', '?')
        dur = o.get('duration_min')
        dur_str = f'{dur}m' if dur else '?'
        title = o.get('title', '')[:35]
        if len(o.get('title', '')) > 35:
            title += '...'
        print(f'    {icon} [{issue}] {title} ({approach}, {dur_str})')
" 2>/dev/null
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════
# SECTION 4: WORK STATUS - What's Open
# ═══════════════════════════════════════════════════════════════════════
echo -e "${CYAN}═══ WORK STATUS ═══${NC}"
echo ""

if [ -f "$DB" ]; then
    # Get counts in single query (2x faster)
    IFS='|' read -r IN_PROG OPEN <<< "$(sqlite3 "$DB" \
        "SELECT
            (SELECT COUNT(*) FROM issues WHERE status='in_progress'),
            (SELECT COUNT(*) FROM issues WHERE status='open')" 2>/dev/null)"

    # In Progress
    echo -e "${GREEN}▶ In Progress: $IN_PROG${NC}"
    sqlite3 -separator '|' "$DB" "
        SELECT id, title FROM issues
        WHERE status='in_progress'
        ORDER BY updated_at DESC LIMIT 5
    " 2>/dev/null | while IFS='|' read -r id title; do
        if [ ${#title} -gt 50 ]; then title="${title:0:47}..."; fi
        echo "    [$id] $title"
    done
    echo ""

    # Ready to work (open, no blockers)
    echo -e "${YELLOW}○ Open: $OPEN${NC}"
    sqlite3 -separator '|' "$DB" "
        SELECT id, title FROM issues
        WHERE status='open'
        ORDER BY priority, updated_at DESC LIMIT 5
    " 2>/dev/null | while IFS='|' read -r id title; do
        if [ ${#title} -gt 50 ]; then title="${title:0:47}..."; fi
        echo "    [$id] $title"
    done
    echo ""

    # Epic progress
    EPIC_STATUS=$(bd epic status 2>/dev/null | grep -v "^$")
    if [ -n "$EPIC_STATUS" ]; then
        echo -e "${BLUE}📊 Epic Progress:${NC}"
        echo "$EPIC_STATUS" | while read -r line; do
            echo "    $line"
        done
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════
# SECTION 5: RECENT CHANGES - Files modified recently
# ═══════════════════════════════════════════════════════════════════════
echo -e "${CYAN}═══ RECENT FILE CHANGES (Last 24h) ═══${NC}"
echo ""

# Find files modified in last 24 hours (excluding .git, node_modules, etc)
find . -type f -mtime -1 \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./.beads/beads.db" \
    -not -path "./.beads/daemon.log" \
    -not -path "./.beads/index/*" \
    -not -name ".DS_Store" \
    2>/dev/null | head -10 | while read -r file; do
    MOD=$(stat -f "%Sm" -t "%H:%M" "$file" 2>/dev/null || echo "??:??")
    echo "  $MOD  $file"
done

TOTAL=$(find . -type f -mtime -1 -not -path "./.git/*" -not -path "./node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL" -gt 10 ]; then
    echo "  ... and $((TOTAL - 10)) more files"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# SECTION 6: BOOKMARKS - Important files to review
# ═══════════════════════════════════════════════════════════════════════
BOOKMARKS=".beads/bookmarks.txt"
if [ -f "$BOOKMARKS" ]; then
    echo -e "${CYAN}═══ BOOKMARKED FILES ═══${NC}"
    echo ""
    while IFS='|' read -r file note; do
        if [ -f "$file" ]; then
            echo "  📌 $file"
            [ -n "$note" ] && echo "     └─ $note"
        fi
    done < "$BOOKMARKS"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════
# SECTION 7: AI CONTEXT TRIGGERS - When to record context
# ═══════════════════════════════════════════════════════════════════════
echo -e "${CYAN}═══ AI CONTEXT TRIGGERS ═══${NC}"
echo ""
echo -e "${YELLOW}Record a DECISION when you:${NC}"
echo "  • Choose between approaches (e.g., 'Using X instead of Y')"
echo "  • Make architecture choices (e.g., 'Put this in services/ not utils/')"
echo "  • Pick a library or tool (e.g., 'Using lodash for deep merge')"
echo "  → am-context <issue> --add-decision \"<what>\" --why \"<reason>\""
echo ""
echo -e "${YELLOW}Record a FINDING when you:${NC}"
echo "  • Discover how existing code works"
echo "  • Find undocumented behavior or gotchas"
echo "  • Learn something that took effort to figure out"
echo "  → am-context <issue> --add-finding \"<discovery>\" --confidence high|medium|low"
echo ""
echo -e "${YELLOW}Record an OUTCOME when you:${NC}"
echo "  • Close an issue (success or failure)"
echo "  • Complete a task to learn what worked"
echo "  → am-outcome record <issue> --success|--failure"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# FOOTER
# ═══════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────────────────────────────"
echo ""
echo "Quick commands:"
echo "  bd ready                    - Issues ready to work"
echo "  bd show <id>                - View issue details"
echo "  am-context <id>             - View/add rich context"
echo "  am-outcome stats            - View outcome statistics"
echo "  am-search <query>           - Search all context"
echo "  am-stats                    - View outcomes dashboard"
echo ""
