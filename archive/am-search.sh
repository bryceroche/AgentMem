#!/bin/bash
# am-search - Enhanced search across all AgentMem data
#
# Features:
# - Fuzzy matching (finds similar words)
# - Ranked results (most relevant first)
# - Multi-term search (AND by default, OR with --or)
# - Searches context, outcomes, and issue titles

show_help() {
    echo "am-search - Enhanced search across all AgentMem data"
    echo ""
    echo "Usage:"
    echo "  am-search <query>              Search for term(s)"
    echo "  am-search <term1> <term2>      Search for multiple terms (AND)"
    echo "  am-search --or <term1> <term2> Search with OR logic"
    echo "  am-search --fuzzy <query>      Enable fuzzy matching"
    echo "  am-search --type <type>        Filter by: note, finding, decision, outcome"
    echo ""
    echo "Options:"
    echo "  -h, --help                     Show this help message"
    echo "  --fuzzy                        Enable fuzzy/approximate matching"
    echo "  --or                           Use OR logic (default is AND)"
    echo "  --type <type>                  Filter by content type"
    echo "  --limit <n>                    Limit results (default: 20)"
    echo ""
    echo "Examples:"
    echo "  am-search postgres             Find mentions of postgres"
    echo "  am-search database migration   Find entries with both terms"
    echo "  am-search --or redis postgres  Find entries with either term"
    echo "  am-search --fuzzy postgre      Fuzzy match (finds postgres)"
    echo "  am-search --type decision sql  Find decisions about SQL"
    exit 0
}

case "$1" in
    -h|--help) show_help ;;
esac

DB=".beads/beads.db"
CONTEXT_FILE=".beads/context.json"
OUTCOMES_FILE=".beads/outcomes.jsonl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required" >&2
    exit 1
fi

if [ ! -f "$CONTEXT_FILE" ]; then
    echo -e "${YELLOW}No context file found.${NC}"
    exit 0
fi

# Parse arguments
FUZZY=false
OR_MODE=false
TYPE_FILTER=""
LIMIT=20
TERMS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fuzzy) FUZZY=true; shift ;;
        --or) OR_MODE=true; shift ;;
        --type) TYPE_FILTER="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        -*) shift ;;  # Skip unknown flags
        *) TERMS+=("$1"); shift ;;
    esac
done

if [ ${#TERMS[@]} -eq 0 ]; then
    show_help
fi

# Join terms for display
QUERY="${TERMS[*]}"
TERMS_JSON=$(printf '%s\n' "${TERMS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")

python3 << EOF
import json
import re
from collections import defaultdict
from difflib import SequenceMatcher

# Load context
with open("$CONTEXT_FILE") as f:
    context = json.load(f)

# Load outcomes
outcomes = []
try:
    with open("$OUTCOMES_FILE") as f:
        for line in f:
            if line.strip():
                outcomes.append(json.loads(line))
except:
    pass

# Load issue titles from beads
issue_titles = {}
try:
    import sqlite3
    conn = sqlite3.connect("$DB")
    for row in conn.execute("SELECT id, title, status FROM issues"):
        issue_titles[row[0]] = {"title": row[1], "status": row[2]}
    conn.close()
except:
    pass

# Search parameters
terms = json.loads('$TERMS_JSON')
fuzzy = "$FUZZY" == "true"
or_mode = "$OR_MODE" == "true"
type_filter = "$TYPE_FILTER"
limit = $LIMIT

def fuzzy_match(text, term, threshold=0.6):
    """Check if term fuzzy-matches any word in text"""
    text_lower = text.lower()
    term_lower = term.lower()

    # Exact substring match
    if term_lower in text_lower:
        return True

    # Fuzzy match against words
    if fuzzy:
        words = re.findall(r'\w+', text_lower)
        for word in words:
            ratio = SequenceMatcher(None, term_lower, word).ratio()
            if ratio >= threshold:
                return True

    return False

def matches_terms(text, terms, or_mode):
    """Check if text matches search terms"""
    if or_mode:
        return any(fuzzy_match(text, term) for term in terms)
    else:
        return all(fuzzy_match(text, term) for term in terms)

def score_match(text, terms):
    """Score relevance of a match (higher = more relevant)"""
    score = 0
    text_lower = text.lower()
    for term in terms:
        term_lower = term.lower()
        # Exact match bonus
        if term_lower in text_lower:
            score += 10
        # Word boundary match bonus
        if re.search(r'\b' + re.escape(term_lower) + r'\b', text_lower):
            score += 5
        # Multiple occurrences
        score += text_lower.count(term_lower) * 2
    return score

# Collect results
results = []

# Search context
for issue_id, ctx in context.items():
    if isinstance(ctx, list):
        ctx = {"notes": ctx}

    # Get issue title
    issue_info = issue_titles.get(issue_id, {})
    issue_title = issue_info.get("title", "")

    # Search notes
    if not type_filter or type_filter == "note":
        for note in ctx.get("notes", []):
            text = note.get("text", "")
            combined = f"{issue_title} {text}"
            if matches_terms(combined, terms, or_mode):
                results.append({
                    "issue": issue_id,
                    "type": "note",
                    "text": text[:80],
                    "date": note.get("date", ""),
                    "score": score_match(combined, terms)
                })

    # Search findings
    if not type_filter or type_filter == "finding":
        for finding in ctx.get("findings", []):
            text = finding.get("text", "")
            combined = f"{issue_title} {text}"
            if matches_terms(combined, terms, or_mode):
                results.append({
                    "issue": issue_id,
                    "type": "finding",
                    "text": text[:80],
                    "date": finding.get("date", ""),
                    "confidence": finding.get("confidence", ""),
                    "score": score_match(combined, terms)
                })

    # Search decisions
    if not type_filter or type_filter == "decision":
        for decision in ctx.get("decisions", []):
            what = decision.get("what", "")
            why = decision.get("why", "")
            combined = f"{issue_title} {what} {why}"
            if matches_terms(combined, terms, or_mode):
                results.append({
                    "issue": issue_id,
                    "type": "decision",
                    "text": f"{what[:40]} - {why[:40]}",
                    "date": decision.get("date", ""),
                    "score": score_match(combined, terms)
                })

# Search outcomes
if not type_filter or type_filter == "outcome":
    for outcome in outcomes:
        title = outcome.get("title", "")
        approach = outcome.get("approach", "")
        combined = f"{title} {approach}"
        if matches_terms(combined, terms, or_mode):
            results.append({
                "issue": outcome.get("issue", ""),
                "type": "outcome",
                "text": title[:60],
                "approach": approach,
                "success": outcome.get("success", False),
                "score": score_match(combined, terms)
            })

# Sort by score (highest first)
results.sort(key=lambda x: -x["score"])

# Display results
print()
query_display = "$QUERY"
mode = "OR" if or_mode else "AND"
fuzzy_str = " (fuzzy)" if fuzzy else ""
print(f"\033[1m🔍 Search: {query_display}\033[0m{fuzzy_str}")
print(f"\033[2mMode: {mode} | Found: {len(results)} | Showing: {min(len(results), limit)}\033[0m")
print("━" * 60)
print()

if not results:
    print("  No matches found.")
    print()
    print("  Tips:")
    print("    - Try fewer terms")
    print("    - Use --fuzzy for approximate matching")
    print("    - Use --or to match any term")
else:
    shown = 0
    for r in results[:limit]:
        issue = r["issue"]
        rtype = r["type"]
        text = r["text"]

        # Type emoji
        emoji = {"note": "📝", "finding": "🔍", "decision": "⚖️", "outcome": "📊"}.get(rtype, "•")

        # Type color
        color = {"note": "\033[0;33m", "finding": "\033[0;32m", "decision": "\033[0;36m", "outcome": "\033[0;35m"}.get(rtype, "")

        print(f"  \033[1;34m{issue}\033[0m {emoji} {color}{rtype}\033[0m")

        # Highlight matching terms in text
        display_text = text
        for term in terms:
            pattern = re.compile(re.escape(term), re.IGNORECASE)
            display_text = pattern.sub(f"\033[1;33m{term}\033[0m", display_text)

        print(f"    {display_text}")

        # Extra info
        if rtype == "outcome":
            success = "✅" if r.get("success") else "❌"
            approach = r.get("approach", "")
            print(f"    {success} {approach}")
        elif r.get("confidence"):
            print(f"    \033[2m[{r['confidence']}]\033[0m")

        print()
        shown += 1

    if len(results) > limit:
        remaining = len(results) - limit
        print(f"\033[2m  ... and {remaining} more (use --limit to see more)\033[0m")
        print()
EOF
