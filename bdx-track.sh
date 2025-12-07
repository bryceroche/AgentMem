#!/bin/bash
# bdx-track - Usage tracking helper for bdx-* scripts
# Source this file in other scripts: source "$(dirname "$0")/bdx-track.sh"

# Track usage to .beads/usage.jsonl
track_usage() {
    local cmd="$1"
    local subcmd="$2"
    shift 2
    local args="$*"

    # Find .beads directory
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.beads" ]]; then
            local usage_file="$dir/.beads/usage.jsonl"
            local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

            # Build JSON (simple, no jq dependency)
            local json="{\"ts\":\"$ts\",\"cmd\":\"$cmd\""
            if [[ -n "$subcmd" ]]; then
                json="$json,\"subcmd\":\"$subcmd\""
            fi
            if [[ -n "$args" ]]; then
                # Escape quotes and limit length
                local safe_args=$(echo "$args" | sed 's/"/\\"/g' | cut -c1-100)
                json="$json,\"args\":\"$safe_args\""
            fi
            json="$json}"

            echo "$json" >> "$usage_file"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}
