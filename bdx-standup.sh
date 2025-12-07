#!/bin/bash
# bdx-standup - Generate standup message for Slack/Discord
#
# Creates a formatted standup from yesterday's closes and today's work.
#
# Usage: bdx-standup [--copy]

set -e

DB=".beads/beads.db"
COPY_TO_CLIPBOARD=false

show_help() {
    echo "bdx-standup - Generate standup message"
    echo ""
    echo "Usage: bdx-standup [options]"
    echo ""
    echo "Options:"
    echo "  --copy       Copy to clipboard (macOS)"
    echo "  --markdown   Use markdown formatting (default)"
    echo "  --plain      Plain text (no formatting)"
    echo "  -h, --help   Show this help"
    exit 0
}

FORMAT="markdown"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help ;;
        --copy) COPY_TO_CLIPBOARD=true; shift ;;
        --plain) FORMAT="plain"; shift ;;
        --markdown) FORMAT="markdown"; shift ;;
        *) shift ;;
    esac
done

# Get date
TODAY=$(date +"%b %d")

# Build standup message
generate_standup() {
    if [ "$FORMAT" = "markdown" ]; then
        echo "📋 **STANDUP** - $TODAY"
        echo ""
    else
        echo "STANDUP - $TODAY"
        echo ""
    fi

    # Yesterday's work (closed yesterday or today if morning)
    if [ -f "$DB" ]; then
        # Get issues closed in last 24 hours
        CLOSED=$(sqlite3 -separator '|' "$DB" "
            SELECT id, title FROM issues
            WHERE status='closed'
            AND datetime(closed_at) > datetime('now', '-24 hours')
            ORDER BY closed_at DESC
            LIMIT 5
        " 2>/dev/null)

        CLOSED_COUNT=$(sqlite3 "$DB" "
            SELECT COUNT(*) FROM issues
            WHERE status='closed'
            AND datetime(closed_at) > datetime('now', '-24 hours')
        " 2>/dev/null || echo "0")

        if [ "$FORMAT" = "markdown" ]; then
            echo "**Yesterday:**"
        else
            echo "Yesterday:"
        fi

        if [ -n "$CLOSED" ]; then
            echo "$CLOSED" | while IFS='|' read -r id title; do
                title="${title:0:50}"
                echo "- $title"
            done
            if [ "$CLOSED_COUNT" -gt 5 ]; then
                echo "- ...and $((CLOSED_COUNT - 5)) more"
            fi
        else
            echo "- (no issues closed)"
        fi
        echo ""

        # Today's focus (in-progress)
        IN_PROGRESS=$(sqlite3 -separator '|' "$DB" "
            SELECT id, title FROM issues
            WHERE status='in_progress'
            ORDER BY priority, updated_at DESC
            LIMIT 3
        " 2>/dev/null)

        if [ "$FORMAT" = "markdown" ]; then
            echo "**Today:**"
        else
            echo "Today:"
        fi

        if [ -n "$IN_PROGRESS" ]; then
            echo "$IN_PROGRESS" | while IFS='|' read -r id title; do
                title="${title:0:50}"
                echo "- $title"
            done
        else
            echo "- Planning next tasks"
        fi
        echo ""

        # Blockers (issues with dependencies that are blocked)
        BLOCKED_COUNT=$(sqlite3 "$DB" "
            SELECT COUNT(DISTINCT i.id) FROM issues i
            JOIN dependencies d ON i.id = d.issue_id
            JOIN issues blocker ON d.depends_on_id = blocker.id
            WHERE i.status IN ('open', 'in_progress')
            AND blocker.status != 'closed'
        " 2>/dev/null || echo "0")

        if [ "$FORMAT" = "markdown" ]; then
            echo "**Blockers:**"
        else
            echo "Blockers:"
        fi

        if [ "$BLOCKED_COUNT" -gt 0 ]; then
            echo "- $BLOCKED_COUNT issue(s) waiting on dependencies"
        else
            echo "- None 🎉"
        fi
    else
        echo "- No beads database found"
    fi
}

# Generate the standup
STANDUP=$(generate_standup)

# Output
echo ""
echo "$STANDUP"
echo ""

# Copy to clipboard if requested
if [ "$COPY_TO_CLIPBOARD" = true ]; then
    if command -v pbcopy &> /dev/null; then
        echo "$STANDUP" | pbcopy
        echo "✅ Copied to clipboard!"
    elif command -v xclip &> /dev/null; then
        echo "$STANDUP" | xclip -selection clipboard
        echo "✅ Copied to clipboard!"
    else
        echo "(clipboard copy not available)"
    fi
    echo ""
fi
