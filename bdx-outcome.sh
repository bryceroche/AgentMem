#!/bin/bash
# bdx-outcome - Track outcomes of completed issues for emergent learning

show_help() {
    echo "bdx-outcome - Track outcomes for emergent learning"
    echo ""
    echo "Usage:"
    echo "  bdx-outcome record <issue> [options]   Record outcome when closing issue"
    echo "  bdx-outcome show <issue>               Show outcome for specific issue"
    echo "  bdx-outcome stats [options]            Show aggregate statistics"
    echo "  bdx-outcome recent [n]                 Show n most recent outcomes"
    echo ""
    echo "Record options:"
    echo "  --success                   Mark as successful (default)"
    echo "  --failure                   Mark as failed"
    echo "  --approach <name>           Approach used (e.g., implement-iterate, research-first)"
    echo "  --complexity <level>        Complexity: low, medium, high"
    echo ""
    echo "Stats options:"
    echo "  --by-approach               Group stats by approach"
    echo "  --by-tag                    Group stats by tag"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  bdx-outcome record issue-abc --success --approach implement-iterate"
    echo "  bdx-outcome record issue-xyz --failure --approach big-bang"
    echo "  bdx-outcome stats --by-approach"
    exit 0
}

# Handle --help
case "$1" in
    -h|--help) show_help ;;
esac

DB=".beads/beads.db"
OUTCOMES_FILE=".beads/outcomes.jsonl"

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed" >&2
    echo "Install with: brew install python3 (macOS) or apt install python3 (Linux)" >&2
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Initialize outcomes file
if [ ! -f "$OUTCOMES_FILE" ]; then
    touch "$OUTCOMES_FILE"
fi

# Record an outcome
record_outcome() {
    local issue="$1"
    local success="${2:-true}"
    local approach="${3:-unknown}"
    local complexity="${4:-medium}"

    # Get issue details from database (single query - 4x faster)
    local title status created updated
    IFS='|' read -r title status created updated <<< "$(sqlite3 "$DB" \
        "SELECT title, status, created_at, updated_at FROM issues WHERE id='$issue'" 2>/dev/null)"

    if [ -z "$title" ]; then
        echo -e "${RED}Issue not found: $issue${NC}"
        return 1
    fi

    # Check if already recorded
    if grep -q "\"issue\": \"$issue\"" "$OUTCOMES_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Outcome already recorded for $issue${NC}"
        return 0
    fi

    python3 << EOF
import json
from datetime import datetime

# Calculate duration if we have timestamps
created = "$created"
updated = "$updated"
duration_min = None

try:
    if created and updated:
        from dateutil import parser
        c = parser.parse(created)
        u = parser.parse(updated)
        duration_min = int((u - c).total_seconds() / 60)
except:
    pass

# Get tags from context if available
tags = []
try:
    with open(".beads/context.json", 'r') as f:
        ctx = json.load(f)
    issue_ctx = ctx.get("$issue", {})
    if isinstance(issue_ctx, dict):
        tags = issue_ctx.get("tags", [])
except:
    pass

# Get blocker count from context
blockers_hit = 0
try:
    with open(".beads/context.json", 'r') as f:
        ctx = json.load(f)
    issue_ctx = ctx.get("$issue", {})
    if isinstance(issue_ctx, dict):
        blockers_hit = len(issue_ctx.get("blockers_resolved", []))
except:
    pass

success_val = "$success".lower() == "true"

outcome = {
    "issue": "$issue",
    "title": """$title""",
    "closed": datetime.now().isoformat(),
    "success": success_val,
    "duration_min": duration_min,
    "approach": "$approach",
    "complexity": "$complexity",
    "tags": tags,
    "blockers_hit": blockers_hit
}

with open("$OUTCOMES_FILE", 'a') as f:
    f.write(json.dumps(outcome) + '\n')

print(f"\033[0;32m✓ Recorded outcome for $issue\033[0m")
print(f"  Success: {'Yes' if success_val else 'No'}")
print(f"  Approach: $approach")
print(f"  Complexity: $complexity")
if duration_min:
    print(f"  Duration: {duration_min} min")
if tags:
    print(f"  Tags: {', '.join(tags)}")
EOF
}

# Show outcome for specific issue
show_outcome() {
    local issue="$1"

    echo ""
    echo -e "${BOLD}📊 Outcome: $issue${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json

found = False
with open("$OUTCOMES_FILE", 'r') as f:
    for line in f:
        if not line.strip():
            continue
        outcome = json.loads(line)
        if outcome.get("issue") == "$issue":
            found = True
            print(f"  Title: {outcome.get('title', 'N/A')}")
            print(f"  Closed: {outcome.get('closed', 'N/A')}")
            print(f"  Success: {'✅ Yes' if outcome.get('success') else '❌ No'}")
            print(f"  Approach: {outcome.get('approach', 'N/A')}")
            print(f"  Complexity: {outcome.get('complexity', 'N/A')}")
            dur = outcome.get('duration_min')
            print(f"  Duration: {dur} min" if dur else "  Duration: N/A")
            tags = outcome.get('tags', [])
            print(f"  Tags: {', '.join(tags) if tags else 'none'}")
            print(f"  Blockers hit: {outcome.get('blockers_hit', 0)}")
            break

if not found:
    print("  No outcome recorded for this issue")
EOF
}

# Show aggregate statistics
show_stats() {
    local group_by="$1"

    echo ""
    echo -e "${BOLD}📊 Outcome Statistics${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json
from collections import defaultdict

outcomes = []
with open("$OUTCOMES_FILE", 'r') as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    print("  No outcomes recorded yet")
    exit(0)

# Overall stats
total = len(outcomes)
successes = sum(1 for o in outcomes if o.get('success'))
durations = [o['duration_min'] for o in outcomes if o.get('duration_min')]
avg_duration = sum(durations) / len(durations) if durations else 0

print(f"\033[1;33mOverall:\033[0m")
print(f"  Total completed: {total}")
print(f"  Success rate: {successes}/{total} ({100*successes//total}%)")
print(f"  Avg duration: {int(avg_duration)} min")
print()

group_by = "$group_by"

if group_by == "approach":
    print(f"\033[1;36mBy Approach:\033[0m")
    by_approach = defaultdict(list)
    for o in outcomes:
        by_approach[o.get('approach', 'unknown')].append(o)

    for approach, items in sorted(by_approach.items()):
        count = len(items)
        success = sum(1 for i in items if i.get('success'))
        durations = [i['duration_min'] for i in items if i.get('duration_min')]
        avg = sum(durations) / len(durations) if durations else 0
        print(f"  {approach}: {count} issues, {100*success//count}% success, ~{int(avg)} min avg")
    print()

elif group_by == "tag":
    print(f"\033[1;35mBy Tag:\033[0m")
    by_tag = defaultdict(list)
    for o in outcomes:
        for tag in o.get('tags', []):
            by_tag[tag].append(o)

    for tag, items in sorted(by_tag.items(), key=lambda x: -len(x[1])):
        count = len(items)
        success = sum(1 for i in items if i.get('success'))
        print(f"  {tag}: {count} issues, {100*success//count}% success")
    print()

elif group_by == "complexity":
    print(f"\033[1;32mBy Complexity:\033[0m")
    by_complexity = defaultdict(list)
    for o in outcomes:
        by_complexity[o.get('complexity', 'unknown')].append(o)

    for complexity in ['low', 'medium', 'high', 'unknown']:
        if complexity in by_complexity:
            items = by_complexity[complexity]
            count = len(items)
            success = sum(1 for i in items if i.get('success'))
            durations = [i['duration_min'] for i in items if i.get('duration_min')]
            avg = sum(durations) / len(durations) if durations else 0
            print(f"  {complexity}: {count} issues, {100*success//count}% success, ~{int(avg)} min avg")
    print()

else:
    # Default: show by complexity
    print(f"\033[1;32mBy Complexity:\033[0m")
    by_complexity = defaultdict(list)
    for o in outcomes:
        by_complexity[o.get('complexity', 'unknown')].append(o)

    for complexity in ['low', 'medium', 'high', 'unknown']:
        if complexity in by_complexity:
            items = by_complexity[complexity]
            count = len(items)
            print(f"  {complexity}: {count} issues")
    print()
EOF
}

# Show recent outcomes
show_recent() {
    local n="${1:-10}"

    echo ""
    echo -e "${BOLD}📋 Recent Outcomes (last $n)${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json

outcomes = []
with open("$OUTCOMES_FILE", 'r') as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    print("  No outcomes recorded yet")
    exit(0)

# Sort by closed date, most recent first
outcomes.sort(key=lambda x: x.get('closed', ''), reverse=True)

for o in outcomes[:$n]:
    issue = o.get('issue', '?')
    success = '✅' if o.get('success') else '❌'
    approach = o.get('approach', '?')
    complexity = o.get('complexity', '?')
    dur = o.get('duration_min')
    dur_str = f"{dur}m" if dur else "?"

    title = o.get('title', '')[:40]
    if len(o.get('title', '')) > 40:
        title += '...'

    print(f"  {success} \033[1;34m{issue}\033[0m [{approach}] [{complexity}] {dur_str}")
    print(f"     {title}")
    print()
EOF
}

# Usage
usage() {
    echo ""
    echo -e "${BOLD}bdx-outcome - Track outcomes for emergent learning${NC}"
    echo ""
    echo "Record:"
    echo "  bdx-outcome record <issue> [--success|--failure] [--approach name] [--complexity low|medium|high]"
    echo ""
    echo "View:"
    echo "  bdx-outcome show <issue>           Show outcome for specific issue"
    echo "  bdx-outcome stats                  Show aggregate statistics"
    echo "  bdx-outcome stats --by-approach    Stats grouped by approach"
    echo "  bdx-outcome stats --by-tag         Stats grouped by tag"
    echo "  bdx-outcome stats --by-complexity  Stats grouped by complexity"
    echo "  bdx-outcome recent [n]             Show n most recent outcomes"
    echo ""
    echo "Examples:"
    echo "  bdx-outcome record impact-abc --success --approach research-first --complexity medium"
    echo "  bdx-outcome stats --by-approach"
    echo ""
}

# Main
case "${1:-}" in
    -h|--help)
        usage
        ;;
    record)
        shift
        issue="$1"
        success="true"
        approach="unknown"
        complexity="medium"
        shift

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --success) success="true"; shift ;;
                --failure) success="false"; shift ;;
                --approach) approach="$2"; shift 2 ;;
                --complexity) complexity="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        if [ -z "$issue" ]; then
            echo "Usage: bdx-outcome record <issue> [options]"
            exit 1
        fi

        record_outcome "$issue" "$success" "$approach" "$complexity"
        ;;
    show)
        show_outcome "$2"
        ;;
    stats)
        case "$2" in
            --by-approach) show_stats "approach" ;;
            --by-tag) show_stats "tag" ;;
            --by-complexity) show_stats "complexity" ;;
            *) show_stats "" ;;
        esac
        ;;
    recent)
        show_recent "${2:-10}"
        ;;
    "")
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
