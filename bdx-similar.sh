#!/bin/bash
# bdx-similar.sh - Find similar past issues based on keywords
#
# Searches issue titles and descriptions, ranks by relevance,
# and optionally shows related context from am-context.
#
# Usage: bdx-similar.sh <keyword> [keyword2...] [options]

set -e

# Track usage
source "$(dirname "$0")/bdx-track.sh" 2>/dev/null && track_usage "bdx-similar" "" "$@"
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ISSUES_FILE=".beads/issues.jsonl"
CONTEXT_FILE=".beads/context.json"
LIMIT=10
SHOW_CONTEXT=false
KEYWORDS=()

show_help() {
    echo "bdx-similar - Find similar past issues based on keywords"
    echo ""
    echo "Usage: bdx-similar.sh <keyword> [keyword2...] [options]"
    echo ""
    echo "Arguments:"
    echo "  keyword     One or more keywords to search for"
    echo ""
    echo "Options:"
    echo "  --limit N   Maximum results to show (default: 10)"
    echo "  --context   Show am-context output for each result"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "Examples:"
    echo "  bdx-similar.sh authentication"
    echo "  bdx-similar.sh stripe payment --limit 5"
    echo "  bdx-similar.sh pipeline agent --context"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --context) SHOW_CONTEXT=true; shift ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) KEYWORDS+=("$1"); shift ;;
    esac
done

if [ ${#KEYWORDS[@]} -eq 0 ]; then
    show_help
fi

# Check dependencies
if [ ! -f "$ISSUES_FILE" ]; then
    echo -e "${RED}Error: No issues.jsonl found${NC}"
    echo "Run 'bd init' first or ensure you're in a beads project."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required${NC}"
    exit 1
fi

# Convert keywords to JSON array for Python
KEYWORDS_JSON=$(printf '%s\n' "${KEYWORDS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")

echo ""
echo -e "${BOLD}🔍 Finding similar issues...${NC}"
echo -e "${DIM}Keywords: ${KEYWORDS[*]}${NC}"
echo ""

# Search and rank issues
python3 << EOF
import json
import re
from collections import defaultdict

# Load issues
issues = []
with open("$ISSUES_FILE") as f:
    for line in f:
        if line.strip():
            try:
                issues.append(json.loads(line))
            except:
                pass

# Load context if available
context = {}
try:
    with open("$CONTEXT_FILE") as f:
        context = json.load(f)
except:
    pass

keywords = json.loads('$KEYWORDS_JSON')
keywords_lower = [k.lower() for k in keywords]

def score_issue(issue):
    """Score an issue based on keyword matches."""
    score = 0
    matches = []

    title = issue.get('title', '').lower()
    desc = issue.get('description', '').lower()

    for kw in keywords_lower:
        # Title matches (higher weight)
        title_count = title.count(kw)
        if title_count > 0:
            score += title_count * 10
            matches.append(f"title:{kw}")

        # Description matches
        desc_count = desc.count(kw)
        if desc_count > 0:
            score += desc_count * 3
            matches.append(f"desc:{kw}")

        # Word boundary bonus
        if re.search(r'\b' + re.escape(kw) + r'\b', title):
            score += 5
        if re.search(r'\b' + re.escape(kw) + r'\b', desc):
            score += 2

    # Recency bonus (closed issues with dates)
    if issue.get('status') == 'closed':
        score += 2  # Completed work is valuable

    return score, matches

# Score all issues
scored = []
for issue in issues:
    score, matches = score_issue(issue)
    if score > 0:
        scored.append({
            'issue': issue,
            'score': score,
            'matches': matches,
            'has_context': issue.get('id', '') in context
        })

# Sort by score descending
scored.sort(key=lambda x: -x['score'])

# Display results
limit = $LIMIT
show_context = "$SHOW_CONTEXT" == "true"

if not scored:
    print("  No similar issues found.")
    print("")
    print("  Tips:")
    print("    - Try different keywords")
    print("    - Use partial words")
    print("    - Check spelling")
else:
    print(f"\033[1m📋 Found {len(scored)} similar issues (showing top {min(len(scored), limit)})\033[0m")
    print("━" * 60)
    print()

    for i, item in enumerate(scored[:limit]):
        issue = item['issue']
        score = item['score']
        issue_id = issue.get('id', '?')
        title = issue.get('title', 'No title')
        status = issue.get('status', '?')

        # Status icon
        status_icon = {
            'open': '○',
            'in_progress': '▶',
            'closed': '✓'
        }.get(status, '?')

        # Status color
        status_color = {
            'open': '\033[1;33m',
            'in_progress': '\033[0;36m',
            'closed': '\033[0;32m'
        }.get(status, '')

        # Score bar
        max_score = scored[0]['score'] if scored else 1
        bar_len = int((score / max_score) * 10)
        bar = '█' * bar_len + '░' * (10 - bar_len)

        print(f"  {status_color}{status_icon}\033[0m \033[1;34m{issue_id}\033[0m {bar} ({score})")
        print(f"    {title[:70]}{'...' if len(title) > 70 else ''}")

        # Show match locations
        if item['matches']:
            match_str = ', '.join(item['matches'][:3])
            print(f"    \033[2mMatches: {match_str}\033[0m")

        # Show context if requested
        if show_context and item['has_context']:
            ctx = context.get(issue_id, {})
            if isinstance(ctx, dict):
                notes = ctx.get('notes', [])[:2]
                decisions = ctx.get('decisions', [])[:1]

                if notes or decisions:
                    print(f"    \033[0;36m─ Context:\033[0m")
                    for note in notes:
                        text = note.get('text', '')[:50]
                        print(f"      📝 {text}...")
                    for dec in decisions:
                        what = dec.get('what', '')[:40]
                        print(f"      ⚖️ {what}...")

        print()

print(f"\033[2mTip: Use --context to see related notes and decisions\033[0m")
print()
EOF
