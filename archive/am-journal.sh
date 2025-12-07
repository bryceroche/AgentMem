#!/bin/bash
# am-journal - Interactive JOURNAL.md setup and management
#
# Creates a rich, guided JOURNAL.md template based on project type

show_help() {
    echo "am-journal - Interactive JOURNAL.md setup and management"
    echo ""
    echo "Usage:"
    echo "  am-journal init              Interactive setup for new projects"
    echo "  am-journal init --template <name>  Use a specific template"
    echo "  am-journal show              Show current journal"
    echo "  am-journal add-pref \"text\"   Add a user preference"
    echo "  am-journal add-decision \"what\" \"why\"  Add a key decision"
    echo "  am-journal add-note \"text\"   Add a session note"
    echo ""
    echo "Templates:"
    echo "  minimal     - Just the basics (preferences, decisions)"
    echo "  standard    - Good for most projects (+ conventions, notes)"
    echo "  consulting  - For client work (+ background, strategy)"
    echo "  oss         - For open source (+ contributing, roadmap)"
    echo ""
    echo "Options:"
    echo "  -h, --help  Show this help message"
    exit 0
}

# Handle --help
case "$1" in
    -h|--help) show_help ;;
esac

JOURNAL=".beads/JOURNAL.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check if .beads exists
check_beads() {
    if [ ! -d ".beads" ]; then
        echo -e "${RED}Error: No .beads directory found${NC}"
        echo "Run 'bd init' first to initialize beads"
        exit 1
    fi
}

# Template: Minimal
template_minimal() {
    local project_name="$1"
    local date=$(date +%Y-%m-%d)

    cat << EOF
# ${project_name} Journal

> **Purpose**: Persistent notes across sessions. Read this at session start.
> **Updated**: ${date}

---

## User Preferences

- Add your preferences here

---

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| | | |

EOF
}

# Template: Standard
template_standard() {
    local project_name="$1"
    local date=$(date +%Y-%m-%d)

    cat << EOF
# ${project_name} Journal

> **Purpose**: Persistent notes across sessions. Read this at session start.
> **Updated**: ${date}

---

## User Preferences

- **Code Style**: (e.g., "tabs vs spaces", "single quotes")
- **Diagrams**: (e.g., "ASCII art only", "Mermaid OK")
- **Git**: (e.g., "squash commits", "conventional commits")
- **Workflow**: (e.g., "use beads for all tasks")
- **Session End**: Always run: git add → bd sync → commit → push

---

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| | | |

---

## Project Conventions

- **File naming**:
- **Branch naming**:
- **Commit format**:

---

## Session Notes

### ${date}
- Initial setup

EOF
}

# Template: Consulting
template_consulting() {
    local project_name="$1"
    local date=$(date +%Y-%m-%d)

    cat << EOF
# ${project_name} Journal

> **Purpose**: Persistent notes across sessions. Read this at session start.
> **Updated**: ${date}

---

## User Preferences

- **Code Style**:
- **Diagrams**: ASCII art preferred for portability
- **Git**: Private repo
- **Workflow**: Use beads for all task tracking
- **Session End**: Always run: git add → bd sync → commit → push

---

## Client Context

| Field | Value |
|-------|-------|
| Client | |
| Project | |
| Timeline | |
| Main Contact | |
| Budget | |

---

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| | | |

---

## Deliverables

| Deliverable | Status | Due Date |
|-------------|--------|----------|
| | | |

---

## Background (for AI context)

### Your Expertise
- Skill 1
- Skill 2

### Key Wins (for credibility)
- Win 1
- Win 2

---

## Session Notes

### ${date}
- Project kickoff

EOF
}

# Template: Open Source
template_oss() {
    local project_name="$1"
    local date=$(date +%Y-%m-%d)

    cat << EOF
# ${project_name} Journal

> **Purpose**: Persistent notes across sessions. Read this at session start.
> **Updated**: ${date}

---

## User Preferences

- **Code Style**: Follow project conventions
- **Diagrams**: ASCII art for docs, Mermaid OK for GitHub
- **Git**: Conventional commits, squash on merge
- **Workflow**: Use beads for task tracking
- **Session End**: Always run: git add → bd sync → commit → push

---

## Project Vision

**What**:
**Why**:
**For Whom**:

---

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| | | |

---

## Roadmap

### v0.1 (MVP)
- [ ] Feature 1
- [ ] Feature 2

### v0.2
- [ ] Feature 3

---

## Contributing Notes

- PR process:
- Review requirements:
- Release process:

---

## Session Notes

### ${date}
- Initial setup

EOF
}

# Interactive init
init_interactive() {
    check_beads

    if [ -f "$JOURNAL" ]; then
        echo -e "${YELLOW}JOURNAL.md already exists.${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo ""
    echo -e "${BOLD}📓 AgentMem Journal Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Get project name
    default_name=$(basename "$(pwd)")
    read -p "Project name [$default_name]: " project_name
    project_name=${project_name:-$default_name}

    echo ""
    echo "Choose a template:"
    echo "  1) minimal    - Just preferences and decisions"
    echo "  2) standard   - Good for most projects"
    echo "  3) consulting - For client work"
    echo "  4) oss        - For open source projects"
    echo ""
    read -p "Template [2]: " template_choice
    template_choice=${template_choice:-2}

    case "$template_choice" in
        1) template_minimal "$project_name" > "$JOURNAL" ;;
        2) template_standard "$project_name" > "$JOURNAL" ;;
        3) template_consulting "$project_name" > "$JOURNAL" ;;
        4) template_oss "$project_name" > "$JOURNAL" ;;
        *) template_standard "$project_name" > "$JOURNAL" ;;
    esac

    echo ""
    echo -e "${GREEN}✓ Created $JOURNAL${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit $JOURNAL to add your preferences"
    echo "  2. Run 'am-prime' to see it in action"
    echo ""
}

# Init with template
init_template() {
    local template="$1"
    check_beads

    local project_name=$(basename "$(pwd)")

    case "$template" in
        minimal) template_minimal "$project_name" > "$JOURNAL" ;;
        standard) template_standard "$project_name" > "$JOURNAL" ;;
        consulting) template_consulting "$project_name" > "$JOURNAL" ;;
        oss) template_oss "$project_name" > "$JOURNAL" ;;
        *)
            echo -e "${RED}Unknown template: $template${NC}"
            echo "Available: minimal, standard, consulting, oss"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Created $JOURNAL with '$template' template${NC}"
}

# Show journal
show_journal() {
    check_beads

    if [ ! -f "$JOURNAL" ]; then
        echo -e "${YELLOW}No JOURNAL.md found. Run 'am-journal init' to create one.${NC}"
        exit 0
    fi

    cat "$JOURNAL"
}

# Add preference
add_preference() {
    local pref="$1"
    check_beads

    if [ ! -f "$JOURNAL" ]; then
        echo -e "${RED}No JOURNAL.md found. Run 'am-journal init' first.${NC}"
        exit 1
    fi

    # Find the preferences section and append
    if grep -q "## User Preferences" "$JOURNAL"; then
        # Add after the preferences header
        sed -i '' "/## User Preferences/a\\
- ${pref}
" "$JOURNAL"
        echo -e "${GREEN}✓ Added preference: ${pref}${NC}"
    else
        echo -e "${RED}Could not find '## User Preferences' section${NC}"
    fi
}

# Add decision
add_decision() {
    local what="$1"
    local why="$2"
    local date=$(date +%Y-%m-%d)
    check_beads

    if [ ! -f "$JOURNAL" ]; then
        echo -e "${RED}No JOURNAL.md found. Run 'am-journal init' first.${NC}"
        exit 1
    fi

    # Find the decisions table and append
    if grep -q "## Key Decisions" "$JOURNAL"; then
        # Find the line after the table header and add
        sed -i '' "/|----------|-----------|/a\\
| ${what} | ${why} | ${date} |
" "$JOURNAL"
        echo -e "${GREEN}✓ Added decision: ${what}${NC}"
    else
        echo -e "${RED}Could not find '## Key Decisions' section${NC}"
    fi
}

# Add session note
add_note() {
    local note="$1"
    local date=$(date +%Y-%m-%d)
    local time=$(date +%H:%M)
    check_beads

    if [ ! -f "$JOURNAL" ]; then
        echo -e "${RED}No JOURNAL.md found. Run 'am-journal init' first.${NC}"
        exit 1
    fi

    # Check if today's section exists
    if grep -q "### $date" "$JOURNAL"; then
        # Add to today's section
        sed -i '' "/### $date/a\\
- [$time] ${note}
" "$JOURNAL"
    else
        # Add new day section at the end
        echo "" >> "$JOURNAL"
        echo "### $date" >> "$JOURNAL"
        echo "- [$time] ${note}" >> "$JOURNAL"
    fi

    echo -e "${GREEN}✓ Added note${NC}"
}

# Main
case "${1:-}" in
    init)
        if [ "$2" = "--template" ] && [ -n "$3" ]; then
            init_template "$3"
        else
            init_interactive
        fi
        ;;
    show)
        show_journal
        ;;
    add-pref)
        add_preference "$2"
        ;;
    add-decision)
        add_decision "$2" "$3"
        ;;
    add-note)
        add_note "$2"
        ;;
    "")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        ;;
esac
