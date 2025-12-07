#!/bin/bash
# bdx-surprise - Detect surprising patterns using statistical confidence intervals
# Surfaces what's worth remembering based on deviation from baseline

set -e

BEADS_DIR=".beads"
# Track usage
source "$(dirname "$0")/bdx-track.sh" 2>/dev/null && track_usage "bdx-surprise" "" "$@"
OUTCOMES_FILE="$BEADS_DIR/outcomes.jsonl"
CONTEXT_FILE="$BEADS_DIR/context.json"
SURPRISE_LOG="$BEADS_DIR/surprise.jsonl"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat << 'EOF'
bdx-surprise - Statistical surprise detection for session memory

USAGE:
    bdx-surprise analyze              Analyze current session for surprises
    bdx-surprise baseline             Show baseline statistics
    bdx-surprise history              Show past surprises
    bdx-surprise add <text>           Manually flag something as surprising

WHAT COUNTS AS SURPRISING (outside 2σ confidence interval):
    - Issue duration significantly longer/shorter than average
    - Error count higher than normal
    - Retry attempts above baseline
    - Approach changes mid-task
    - Explicit markers: "actually", "wait", "oops", "remember"

EXAMPLES:
    bdx-surprise analyze              # Scan for statistical outliers
    bdx-surprise baseline             # See what "normal" looks like
    bdx-surprise add "SQLite uses ? not $1 for placeholders"
EOF
}

# Calculate mean and stddev from outcomes
calc_baseline() {
    if [[ ! -f "$OUTCOMES_FILE" ]]; then
        echo "0 0 0"  # mean, stddev, count
        return
    fi

    # Extract durations (in minutes) from outcomes
    local durations=$(jq -r '
        select(.duration_min != null and .duration_min > 0) |
        .duration_min
    ' "$OUTCOMES_FILE" 2>/dev/null | grep -v '^$')

    if [[ -z "$durations" ]]; then
        echo "0 0 0"
        return
    fi

    # Calculate mean and stddev using awk
    echo "$durations" | awk '
    {
        sum += $1
        sumsq += $1 * $1
        count++
    }
    END {
        if (count > 0) {
            mean = sum / count
            variance = (sumsq / count) - (mean * mean)
            if (variance < 0) variance = 0
            stddev = sqrt(variance)
            printf "%.2f %.2f %d\n", mean, stddev, count
        } else {
            print "0 0 0"
        }
    }'
}

# Calculate error baseline from context
calc_error_baseline() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        echo "0 0 0"
        return
    fi

    # Count errors per issue from context
    local error_counts=$(jq -r '
        .issues[]? |
        [.entries[]? | select(.type == "error" or .type == "fix")] |
        length
    ' "$CONTEXT_FILE" 2>/dev/null | grep -v '^$')

    if [[ -z "$error_counts" ]]; then
        echo "0 0 0"
        return
    fi

    echo "$error_counts" | awk '
    {
        sum += $1
        sumsq += $1 * $1
        count++
    }
    END {
        if (count > 0) {
            mean = sum / count
            variance = (sumsq / count) - (mean * mean)
            if (variance < 0) variance = 0
            stddev = sqrt(variance)
            printf "%.2f %.2f %d\n", mean, stddev, count
        } else {
            print "0 0 0"
        }
    }'
}

# Check if value is outside confidence interval (2 sigma)
is_surprising() {
    local value=$1
    local mean=$2
    local stddev=$3
    local sigma=${4:-2}  # Default 2 sigma (95% confidence)

    # If no baseline yet, nothing is surprising
    if [[ "$stddev" == "0" || "$stddev" == "0.00" ]]; then
        echo "false"
        return
    fi

    # Calculate z-score
    local z_score=$(echo "$value $mean $stddev" | awk '{
        if ($3 > 0) {
            z = ($1 - $2) / $3
            if (z < 0) z = -z
            print z
        } else {
            print 0
        }
    }')

    # Check if outside confidence interval
    local is_outside=$(echo "$z_score $sigma" | awk '{print ($1 > $2) ? "true" : "false"}')
    echo "$is_outside"
}

# Show baseline statistics
show_baseline() {
    echo -e "${CYAN}═══ BASELINE STATISTICS ═══${NC}"
    echo ""

    # Duration baseline
    read -r dur_mean dur_stddev dur_count <<< $(calc_baseline)
    echo -e "${YELLOW}Task Duration (minutes):${NC}"
    echo "  Mean: $dur_mean"
    echo "  StdDev: $dur_stddev"
    echo "  Sample size: $dur_count"
    echo "  95% CI: [$(echo "$dur_mean $dur_stddev" | awk '{printf "%.1f", $1 - 2*$2}'), $(echo "$dur_mean $dur_stddev" | awk '{printf "%.1f", $1 + 2*$2}')]"
    echo ""

    # Error baseline
    read -r err_mean err_stddev err_count <<< $(calc_error_baseline)
    echo -e "${YELLOW}Errors per Issue:${NC}"
    echo "  Mean: $err_mean"
    echo "  StdDev: $err_stddev"
    echo "  Sample size: $err_count"
    echo "  95% CI: [$(echo "$err_mean $err_stddev" | awk '{printf "%.1f", $1 - 2*$2}'), $(echo "$err_mean $err_stddev" | awk '{printf "%.1f", $1 + 2*$2}')]"
    echo ""

    # Pattern markers baseline
    echo -e "${YELLOW}Surprise Markers:${NC}"
    echo "  'actually/wait/oops' = Course correction"
    echo "  'remember/note' = Explicit memory flag"
    echo "  Error → Fix sequence = Problem solved"
}

# Analyze for surprises
analyze() {
    echo -e "${CYAN}═══ SURPRISE ANALYSIS ═══${NC}"
    echo ""

    local found_surprises=0

    # Get baselines
    read -r dur_mean dur_stddev dur_count <<< $(calc_baseline)
    read -r err_mean err_stddev err_count <<< $(calc_error_baseline)

    # Check recent outcomes for duration outliers
    if [[ -f "$OUTCOMES_FILE" ]]; then
        echo -e "${YELLOW}Duration Outliers:${NC}"

        while IFS= read -r line; do
            local issue_id=$(echo "$line" | jq -r '.issue // empty')
            local duration=$(echo "$line" | jq -r '.duration_min // 0')
            local title=$(echo "$line" | jq -r '.title // "unknown"' | cut -c1-50)

            if [[ -n "$issue_id" && "$duration" != "0" && "$duration" != "null" ]]; then
                local surprising=$(is_surprising "$duration" "$dur_mean" "$dur_stddev")
                if [[ "$surprising" == "true" ]]; then
                    local z=$(echo "$duration $dur_mean $dur_stddev" | awk '{if($3>0) printf "%.1f", ($1-$2)/$3; else print "0"}')
                    if (( $(echo "$duration > $dur_mean" | bc -l) )); then
                        echo -e "  ${RED}⚠${NC} [$issue_id] ${duration}min (z=+$z) - $title"
                        echo "    → Took longer than expected. Worth noting why?"
                    else
                        echo -e "  ${GREEN}★${NC} [$issue_id] ${duration}min (z=$z) - $title"
                        echo "    → Completed faster than usual. Reusable approach?"
                    fi
                    found_surprises=$((found_surprises + 1))
                fi
            fi
        done < <(tail -20 "$OUTCOMES_FILE" 2>/dev/null)

        if [[ $found_surprises -eq 0 ]]; then
            echo "  No duration outliers in recent outcomes"
        fi
        echo ""
    fi

    # Check context for error clusters
    if [[ -f "$CONTEXT_FILE" ]]; then
        echo -e "${YELLOW}Error Clusters:${NC}"
        local error_surprises=0

        jq -r '
            .issues | to_entries[] |
            select(.value.entries != null) |
            {
                id: .key,
                errors: [.value.entries[] | select(.type == "error" or .type == "fix")] | length,
                title: .value.title
            } |
            select(.errors > 0) |
            "\(.id)\t\(.errors)\t\(.title)"
        ' "$CONTEXT_FILE" 2>/dev/null | while IFS=$'\t' read -r issue_id error_count title; do
            local surprising=$(is_surprising "$error_count" "$err_mean" "$err_stddev")
            if [[ "$surprising" == "true" ]]; then
                echo -e "  ${RED}⚠${NC} [$issue_id] $error_count errors - $title"
                echo "    → Higher than usual error count. Document the fix?"
                error_surprises=$((error_surprises + 1))
            fi
        done

        if [[ $error_surprises -eq 0 ]]; then
            echo "  No error clusters above baseline"
        fi
        echo ""
    fi

    # Pattern-based surprises (keyword scanning)
    echo -e "${YELLOW}Pattern Markers (scan recent context):${NC}"
    if [[ -f "$CONTEXT_FILE" ]]; then
        local patterns=0

        # Look for correction patterns in context entries
        jq -r '
            .issues | to_entries[] |
            .value.entries[]? |
            select(.content != null) |
            select(
                (.content | test("actually|wait|oops|realized|mistake|wrong"; "i")) or
                (.content | test("remember|note:|important:|key insight"; "i"))
            ) |
            "  → \(.content[0:100])"
        ' "$CONTEXT_FILE" 2>/dev/null | head -10 | while read -r line; do
            echo -e "${YELLOW}$line${NC}"
            patterns=$((patterns + 1))
        done

        if [[ $patterns -eq 0 ]]; then
            echo "  No explicit markers found"
        fi
    fi

    echo ""
    echo -e "${CYAN}─────────────────────────────────────────${NC}"
    echo "Use 'bdx-surprise add <text>' to manually flag surprises"
}

# Add manual surprise entry
add_surprise() {
    local text="$*"
    if [[ -z "$text" ]]; then
        echo "Error: Provide surprise text"
        exit 1
    fi

    local entry=$(jq -n \
        --arg text "$text" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg type "manual" \
        '{timestamp: $ts, type: $type, content: $text}')

    echo "$entry" >> "$SURPRISE_LOG"
    echo -e "${GREEN}✓${NC} Logged surprise: $text"
}

# Show surprise history
show_history() {
    if [[ ! -f "$SURPRISE_LOG" ]]; then
        echo "No surprises logged yet"
        exit 0
    fi

    echo -e "${CYAN}═══ SURPRISE HISTORY ═══${NC}"
    echo ""

    jq -r '
        "\(.timestamp[0:10]) [\(.type)] \(.content)"
    ' "$SURPRISE_LOG" | tail -20
}

# Main
case "${1:-}" in
    analyze|"")
        analyze
        ;;
    baseline)
        show_baseline
        ;;
    history)
        show_history
        ;;
    add)
        shift
        add_surprise "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
