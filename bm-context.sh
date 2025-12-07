#!/bin/bash
# bm-context - Rich context trails for beads issues
#
# Enhanced with: findings, decisions, tags, related issues, blockers

show_help() {
    echo "bm-context - Rich context trails for beads issues"
    echo ""
    echo "Usage:"
    echo "  bm-context <issue>                    Show all context for issue"
    echo "  bm-context <issue> --add \"text\"       Add a note"
    echo "  bm-context <issue> --add-finding \"text\" [--source src] [--confidence high|medium|low]"
    echo "  bm-context <issue> --add-decision \"what\" --why \"reason\" [--alternatives \"a,b,c\"]"
    echo "  bm-context <issue> --add-tag \"tag1,tag2\""
    echo "  bm-context <issue> --link \"other-issue\""
    echo "  bm-context <issue> --resolved \"blocker\" --resolution \"how fixed\""
    echo ""
    echo "Search:"
    echo "  bm-context --search \"keyword\"        Search across all context"
    echo "  bm-context --tag \"tagname\"           Find issues by tag"
    echo "  bm-context --list                    List all issues with context"
    echo ""
    echo "Options:"
    echo "  -h, --help                           Show this help message"
    echo ""
    echo "Examples:"
    echo "  bm-context issue-abc --add \"Discovered the API rate limits\""
    echo "  bm-context issue-abc --add-finding \"Redis is bottleneck\" --confidence high"
    echo "  bm-context issue-abc --add-decision \"Use PostgreSQL\" --why \"Better for our scale\""
    exit 0
}

# Handle --help
case "$1" in
    -h|--help) show_help ;;
esac

DB=".beads/beads.db"
CONTEXT_FILE=".beads/context.json"
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

# Initialize files
if [ ! -f "$CONTEXT_FILE" ]; then
    echo "{}" > "$CONTEXT_FILE"
fi
if [ ! -f "$OUTCOMES_FILE" ]; then
    touch "$OUTCOMES_FILE"
fi

# Show rich context with formatting
show_context() {
    local issue="$1"
    local filter="$2"

    # Get issue details (single query)
    IFS='|' read -r TITLE STATUS <<< "$(sqlite3 "$DB" "SELECT title, status FROM issues WHERE id='$issue'" 2>/dev/null)"

    echo ""
    echo -e "${BOLD}📋 Context: $issue${NC}"
    if [ -n "$TITLE" ]; then
        echo -e "   ${CYAN}$TITLE${NC}"
        echo -e "   Status: $STATUS"
    fi
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json
import sys

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

issue_ctx = ctx.get("$issue", {})

# Handle legacy format (array of {date, text})
if isinstance(issue_ctx, list):
    issue_ctx = {"notes": issue_ctx}

if not issue_ctx:
    print("  (no context yet)")
    print("")
    print("  Add context with:")
    print("    bm-context $issue --add \"note\"")
    print("    bm-context $issue --add-finding \"discovery\"")
    print("    bm-context $issue --add-decision \"what\" --why \"reason\"")
    sys.exit(0)

filter_type = "$filter"

# Notes (legacy "rationale" format)
if (not filter_type or filter_type == "notes") and "notes" in issue_ctx and issue_ctx["notes"]:
    print("\033[1;33m📝 Notes:\033[0m")
    for note in issue_ctx["notes"]:
        date = note.get("date", "?")
        text = note.get("text", "")
        print(f"  [{date}] {text}")
    print()

# Findings
if (not filter_type or filter_type == "findings") and "findings" in issue_ctx and issue_ctx["findings"]:
    print("\033[1;32m🔍 Findings:\033[0m")
    for f in issue_ctx["findings"]:
        date = f.get("date", "?")
        text = f.get("text", "")
        source = f.get("source", "")
        conf = f.get("confidence", "")
        source_str = f" (source: {source})" if source else ""
        conf_str = f" [{conf}]" if conf else ""
        print(f"  [{date}]{conf_str} {text}{source_str}")
    print()

# Decisions
if (not filter_type or filter_type == "decisions") and "decisions" in issue_ctx and issue_ctx["decisions"]:
    print("\033[1;36m⚖️  Decisions:\033[0m")
    for d in issue_ctx["decisions"]:
        date = d.get("date", "?")
        what = d.get("what", "")
        why = d.get("why", "")
        alts = d.get("alternatives", [])
        print(f"  [{date}] {what}")
        if why:
            print(f"      Why: {why}")
        if alts:
            print(f"      Alternatives: {', '.join(alts)}")
    print()

# Tags
if (not filter_type) and "tags" in issue_ctx and issue_ctx["tags"]:
    tags = issue_ctx["tags"]
    print(f"\033[1;35m🏷️  Tags:\033[0m {', '.join(tags)}")
    print()

# Related issues
if (not filter_type) and "related" in issue_ctx and issue_ctx["related"]:
    related = issue_ctx["related"]
    print(f"\033[1;34m🔗 Related:\033[0m {', '.join(related)}")
    print()

# Blockers resolved
if (not filter_type or filter_type == "blockers") and "blockers_resolved" in issue_ctx and issue_ctx["blockers_resolved"]:
    print("\033[1;31m✅ Blockers Resolved:\033[0m")
    for b in issue_ctx["blockers_resolved"]:
        date = b.get("date", "?")
        blocker = b.get("blocker", "")
        resolution = b.get("resolution", "")
        print(f"  [{date}] {blocker}")
        if resolution:
            print(f"      → {resolution}")
    print()
EOF
}

# Ensure issue has proper structure
ensure_structure() {
    local issue="$1"
    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

if "$issue" not in ctx:
    ctx["$issue"] = {"notes": [], "findings": [], "decisions": [], "tags": [], "related": [], "blockers_resolved": []}
elif isinstance(ctx["$issue"], list):
    # Migrate legacy format
    ctx["$issue"] = {"notes": ctx["$issue"], "findings": [], "decisions": [], "tags": [], "related": [], "blockers_resolved": []}
else:
    # Ensure all fields exist
    for field in ["notes", "findings", "decisions", "tags", "related", "blockers_resolved"]:
        if field not in ctx["$issue"]:
            ctx["$issue"][field] = []

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
}

# Add note (legacy compatible)
add_note() {
    local issue="$1"
    local text="$2"
    ensure_structure "$issue"

    python3 << EOF
import json
from datetime import datetime

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

ctx["$issue"]["notes"].append({
    "date": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "text": """$text"""
})

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
    echo -e "${GREEN}✓ Added note to $issue${NC}"
}

# Add finding
add_finding() {
    local issue="$1"
    local text="$2"
    local source="$3"
    local confidence="$4"
    ensure_structure "$issue"

    python3 << EOF
import json
from datetime import datetime

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

finding = {
    "date": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "text": """$text"""
}
if "$source":
    finding["source"] = "$source"
if "$confidence":
    finding["confidence"] = "$confidence"

ctx["$issue"]["findings"].append(finding)

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
    echo -e "${GREEN}✓ Added finding to $issue${NC}"
}

# Add decision
add_decision() {
    local issue="$1"
    local what="$2"
    local why="$3"
    local alternatives="$4"
    ensure_structure "$issue"

    python3 << EOF
import json
from datetime import datetime

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

decision = {
    "date": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "what": """$what""",
    "why": """$why"""
}
if "$alternatives":
    decision["alternatives"] = [a.strip() for a in "$alternatives".split(",")]

ctx["$issue"]["decisions"].append(decision)

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
    echo -e "${GREEN}✓ Added decision to $issue${NC}"
}

# Add tags
add_tags() {
    local issue="$1"
    local tags="$2"
    ensure_structure "$issue"

    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

new_tags = [t.strip() for t in "$tags".split(",")]
existing = set(ctx["$issue"]["tags"])
added = []
for t in new_tags:
    if t and t not in existing:
        ctx["$issue"]["tags"].append(t)
        added.append(t)

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)

if added:
    print(f"\033[0;32m✓ Added tags: {', '.join(added)}\033[0m")
else:
    print("Tags already exist")
EOF
}

# Link related issue
add_link() {
    local issue="$1"
    local related="$2"
    ensure_structure "$issue"

    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

if "$related" not in ctx["$issue"]["related"]:
    ctx["$issue"]["related"].append("$related")

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
    echo -e "${GREEN}✓ Linked $issue → $related${NC}"
}

# Add resolved blocker
add_resolved() {
    local issue="$1"
    local blocker="$2"
    local resolution="$3"
    ensure_structure "$issue"

    python3 << EOF
import json
from datetime import datetime

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

ctx["$issue"]["blockers_resolved"].append({
    "date": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "blocker": """$blocker""",
    "resolution": """$resolution"""
})

with open("$CONTEXT_FILE", 'w') as f:
    json.dump(ctx, f, indent=2)
EOF
    echo -e "${GREEN}✓ Recorded resolved blocker${NC}"
}

# Search across all context
search_context() {
    local query="$1"

    echo ""
    echo -e "${BOLD}🔍 Searching for: $query${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

query = "$query".lower()
matches = []

for issue_id, issue_ctx in ctx.items():
    if isinstance(issue_ctx, list):
        issue_ctx = {"notes": issue_ctx}

    found_in = []

    for note in issue_ctx.get("notes", []):
        if query in note.get("text", "").lower():
            found_in.append(("note", note['text'][:60]))

    for finding in issue_ctx.get("findings", []):
        if query in finding.get("text", "").lower():
            found_in.append(("finding", finding['text'][:60]))

    for decision in issue_ctx.get("decisions", []):
        if query in decision.get("what", "").lower() or query in decision.get("why", "").lower():
            found_in.append(("decision", decision['what'][:60]))

    if found_in:
        matches.append((issue_id, found_in))

if not matches:
    print("  No matches found")
else:
    for issue_id, found_in in matches:
        print(f"\033[1;34m{issue_id}\033[0m")
        for ftype, text in found_in[:3]:
            print(f"  [{ftype}] {text}...")
        if len(found_in) > 3:
            print(f"  ... and {len(found_in) - 3} more")
        print()
EOF
}

# Find by tag
find_by_tag() {
    local tag="$1"

    echo ""
    echo -e "${BOLD}🏷️  Issues tagged: $tag${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

tag = "$tag".lower()
matches = []

for issue_id, issue_ctx in ctx.items():
    if isinstance(issue_ctx, list):
        continue
    tags = [t.lower() for t in issue_ctx.get("tags", [])]
    if tag in tags:
        matches.append(issue_id)

if not matches:
    print("  No issues with this tag")
else:
    for issue_id in matches:
        print(f"  • {issue_id}")
EOF
}

# List all issues with context
list_context() {
    echo ""
    echo -e "${BOLD}📋 Issues with context${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    python3 << EOF
import json

with open("$CONTEXT_FILE", 'r') as f:
    ctx = json.load(f)

for issue_id, issue_ctx in sorted(ctx.items()):
    if isinstance(issue_ctx, list):
        count = len(issue_ctx)
        print(f"  \033[1;34m{issue_id}\033[0m: {count} notes (legacy)")
    else:
        parts = []
        n = len(issue_ctx.get("notes", []))
        f = len(issue_ctx.get("findings", []))
        d = len(issue_ctx.get("decisions", []))
        t = issue_ctx.get("tags", [])

        if n: parts.append(f"{n} notes")
        if f: parts.append(f"{f} findings")
        if d: parts.append(f"{d} decisions")
        if t: parts.append(f"tags: {','.join(t[:3])}")

        summary = ", ".join(parts) if parts else "(empty)"
        print(f"  \033[1;34m{issue_id}\033[0m: {summary}")
EOF
    echo ""
}

# Usage
usage() {
    echo ""
    echo -e "${BOLD}bm-context - Rich context trails for beads issues${NC}"
    echo ""
    echo "View context:"
    echo "  bm-context <issue>                Show all context"
    echo "  bm-context <issue> --findings     Show only findings"
    echo "  bm-context <issue> --decisions    Show only decisions"
    echo ""
    echo "Add context:"
    echo "  bm-context <issue> --add \"text\"                       Add note"
    echo "  bm-context <issue> --add-finding \"text\" [--source s] [--confidence high|medium|low]"
    echo "  bm-context <issue> --add-decision \"what\" --why \"reason\" [--alternatives \"a,b\"]"
    echo "  bm-context <issue> --add-tag \"tag1,tag2\""
    echo "  bm-context <issue> --link \"other-issue\""
    echo "  bm-context <issue> --resolved \"blocker\" --resolution \"how fixed\""
    echo ""
    echo "Search:"
    echo "  bm-context --search \"keyword\""
    echo "  bm-context --tag \"tagname\""
    echo "  bm-context --list"
    echo ""
}

# Main
case "${1:-}" in
    -h|--help)
        usage
        ;;
    --search)
        search_context "$2"
        ;;
    --tag)
        find_by_tag "$2"
        ;;
    --list)
        list_context
        ;;
    "")
        usage
        ;;
    *)
        issue="$1"
        shift

        case "${1:-}" in
            --findings|--decisions|--notes|--blockers)
                filter="${1#--}"
                show_context "$issue" "$filter"
                ;;
            --add)
                add_note "$issue" "$2"
                ;;
            --add-finding)
                text="$2"
                source=""
                confidence=""
                shift 2
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --source) source="$2"; shift 2 ;;
                        --confidence) confidence="$2"; shift 2 ;;
                        *) shift ;;
                    esac
                done
                add_finding "$issue" "$text" "$source" "$confidence"
                ;;
            --add-decision)
                what="$2"
                why=""
                alternatives=""
                shift 2
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --why) why="$2"; shift 2 ;;
                        --alternatives) alternatives="$2"; shift 2 ;;
                        *) shift ;;
                    esac
                done
                add_decision "$issue" "$what" "$why" "$alternatives"
                ;;
            --add-tag)
                add_tags "$issue" "$2"
                ;;
            --link)
                add_link "$issue" "$2"
                ;;
            --resolved)
                blocker="$2"
                resolution=""
                shift 2
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --resolution) resolution="$2"; shift 2 ;;
                        *) shift ;;
                    esac
                done
                add_resolved "$issue" "$blocker" "$resolution"
                ;;
            --show|"")
                show_context "$issue" ""
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
        ;;
esac
