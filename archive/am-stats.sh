#!/bin/bash
# am-stats - Visualize outcomes with ASCII charts
#
# Shows trends, patterns, and insights from completed work

show_help() {
    echo "am-stats - Visualize outcomes with ASCII charts"
    echo ""
    echo "Usage:"
    echo "  am-stats                    Full dashboard"
    echo "  am-stats summary            Quick summary stats"
    echo "  am-stats approaches         Success rate by approach (bar chart)"
    echo "  am-stats complexity         Success rate by complexity"
    echo "  am-stats timeline           Outcomes over time"
    echo "  am-stats streak             Current success/failure streak"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message"
    exit 0
}

case "$1" in
    -h|--help) show_help ;;
esac

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

if [ ! -f "$OUTCOMES_FILE" ]; then
    echo -e "${YELLOW}No outcomes recorded yet.${NC}"
    echo "Use 'am-outcome record <issue>' when closing issues."
    exit 0
fi

# Summary stats
show_summary() {
    python3 << 'EOF'
import json
from datetime import datetime, timedelta
from collections import Counter

outcomes = []
with open(".beads/outcomes.jsonl") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    print("No outcomes recorded yet.")
    exit()

total = len(outcomes)
successes = sum(1 for o in outcomes if o.get("success"))
failures = total - successes
rate = (successes / total * 100) if total else 0

# Recent (last 7 days)
week_ago = datetime.now() - timedelta(days=7)
recent = [o for o in outcomes if datetime.fromisoformat(o["closed"].replace("Z", "")) > week_ago]
recent_success = sum(1 for o in recent if o.get("success"))

print()
print("\033[1m📊 OUTCOME SUMMARY\033[0m")
print("━" * 40)
print()
print(f"  Total completed:  {total}")
print(f"  Successful:       {successes} ({rate:.0f}%)")
print(f"  Failed:           {failures}")
print()
print(f"  Last 7 days:      {len(recent)} completed, {recent_success} successful")
print()
EOF
}

# Bar chart helper
bar_chart() {
    python3 << 'EOF'
import json
from collections import Counter

outcomes = []
with open(".beads/outcomes.jsonl") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    exit()

# Group by approach
approaches = Counter()
successes = Counter()

for o in outcomes:
    approach = o.get("approach", "unknown")
    approaches[approach] += 1
    if o.get("success"):
        successes[approach] += 1

print()
print("\033[1m📈 SUCCESS RATE BY APPROACH\033[0m")
print("━" * 50)
print()

max_count = max(approaches.values()) if approaches else 1
bar_width = 25

for approach, count in sorted(approaches.items(), key=lambda x: -x[1]):
    success = successes[approach]
    rate = (success / count * 100) if count else 0

    # Create bar
    filled = int((count / max_count) * bar_width)
    bar = "█" * filled + "░" * (bar_width - filled)

    # Color based on success rate
    if rate >= 80:
        color = "\033[0;32m"  # Green
    elif rate >= 50:
        color = "\033[1;33m"  # Yellow
    else:
        color = "\033[0;31m"  # Red

    print(f"  {approach:20} {color}{bar}\033[0m {success}/{count} ({rate:.0f}%)")

print()
EOF
}

# Complexity breakdown
complexity_chart() {
    python3 << 'EOF'
import json
from collections import Counter

outcomes = []
with open(".beads/outcomes.jsonl") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    exit()

# Group by complexity
complexities = Counter()
successes = Counter()

for o in outcomes:
    complexity = o.get("complexity", "unknown")
    complexities[complexity] += 1
    if o.get("success"):
        successes[complexity] += 1

print()
print("\033[1m🎯 SUCCESS RATE BY COMPLEXITY\033[0m")
print("━" * 50)
print()

order = ["low", "medium", "high", "unknown"]
max_count = max(complexities.values()) if complexities else 1
bar_width = 25

for complexity in order:
    if complexity not in complexities:
        continue
    count = complexities[complexity]
    success = successes[complexity]
    rate = (success / count * 100) if count else 0

    # Create bar
    filled = int((count / max_count) * bar_width)
    bar = "█" * filled + "░" * (bar_width - filled)

    # Emoji for complexity
    emoji = {"low": "🟢", "medium": "🟡", "high": "🔴"}.get(complexity, "⚪")

    print(f"  {emoji} {complexity:10} {bar} {success}/{count} ({rate:.0f}%)")

print()
EOF
}

# Timeline
timeline_chart() {
    python3 << 'EOF'
import json
from datetime import datetime, timedelta
from collections import defaultdict

outcomes = []
with open(".beads/outcomes.jsonl") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    exit()

# Group by date
by_date = defaultdict(lambda: {"success": 0, "fail": 0})

for o in outcomes:
    date = datetime.fromisoformat(o["closed"].replace("Z", "")).strftime("%Y-%m-%d")
    if o.get("success"):
        by_date[date]["success"] += 1
    else:
        by_date[date]["fail"] += 1

print()
print("\033[1m📅 OUTCOMES TIMELINE (Last 14 days)\033[0m")
print("━" * 50)
print()

# Show last 14 days
today = datetime.now()
for i in range(13, -1, -1):
    date = (today - timedelta(days=i)).strftime("%Y-%m-%d")
    day_name = (today - timedelta(days=i)).strftime("%a")
    data = by_date.get(date, {"success": 0, "fail": 0})

    s = data["success"]
    f = data["fail"]

    if s == 0 and f == 0:
        bar = "\033[2m·\033[0m"
    else:
        bar = "\033[0;32m●\033[0m" * s + "\033[0;31m●\033[0m" * f

    # Highlight today
    if i == 0:
        print(f"  {day_name} {date} {bar} \033[1m← today\033[0m")
    else:
        print(f"  {day_name} {date} {bar}")

print()
print("  \033[0;32m●\033[0m = success  \033[0;31m●\033[0m = failure  \033[2m·\033[0m = no activity")
print()
EOF
}

# Streak
show_streak() {
    python3 << 'EOF'
import json
from datetime import datetime

outcomes = []
with open(".beads/outcomes.jsonl") as f:
    for line in f:
        if line.strip():
            outcomes.append(json.loads(line))

if not outcomes:
    exit()

# Sort by date
outcomes.sort(key=lambda x: x["closed"], reverse=True)

# Calculate streak
streak = 0
streak_type = None

for o in outcomes:
    if streak_type is None:
        streak_type = o.get("success")
        streak = 1
    elif o.get("success") == streak_type:
        streak += 1
    else:
        break

print()
print("\033[1m🔥 CURRENT STREAK\033[0m")
print("━" * 40)
print()

if streak_type:
    emoji = "🎉" if streak >= 5 else "✅"
    print(f"  {emoji} {streak} successful in a row!")
else:
    print(f"  ❌ {streak} failed in a row")

# Best streak ever
best_streak = 0
current = 0
for o in sorted(outcomes, key=lambda x: x["closed"]):
    if o.get("success"):
        current += 1
        best_streak = max(best_streak, current)
    else:
        current = 0

print(f"  🏆 Best ever: {best_streak} successes")
print()
EOF
}

# Full dashboard
dashboard() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║              AGENTMEM OUTCOMES DASHBOARD                  ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"

    show_summary
    bar_chart
    complexity_chart
    show_streak
    timeline_chart
}

# Main
case "${1:-}" in
    summary)
        show_summary
        ;;
    approaches)
        bar_chart
        ;;
    complexity)
        complexity_chart
        ;;
    timeline)
        timeline_chart
        ;;
    streak)
        show_streak
        ;;
    "")
        dashboard
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        ;;
esac
