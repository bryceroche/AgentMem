#!/bin/bash
# AgentMem Installer
# Memory layer for AI coding agents
#
# Usage: curl -sSL <url> | bash
#    or: ./install.sh [--local]

set -e

AGENTMEM_VERSION="0.1.0"
INSTALL_DIR="${AGENTMEM_DIR:-$HOME/.agentmem}"
BIN_DIR="${AGENTMEM_BIN:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              AgentMem v${AGENTMEM_VERSION} Installer                       ║${NC}"
echo -e "${CYAN}║         Memory Layer for AI Coding Agents                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required but not installed${NC}"
    echo "Install with: brew install python3 (macOS) or apt install python3 (Linux)"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} python3"

if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}Error: sqlite3 is required but not installed${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} sqlite3"

if ! command -v bd &> /dev/null; then
    echo -e "${YELLOW}  ⚠ beads (bd) not found - AgentMem works best with beads${NC}"
    echo "    Install from: https://github.com/steveyegge/beads"
else
    echo -e "  ${GREEN}✓${NC} beads (bd)"
fi

echo ""

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
echo -e "  ${GREEN}✓${NC} $INSTALL_DIR"
echo -e "  ${GREEN}✓${NC} $BIN_DIR"
echo ""

# Copy scripts
echo -e "${YELLOW}Installing scripts...${NC}"

# Determine source (local or download)
if [ "$1" = "--local" ] || [ -f "$(dirname "$0")/am-prime.sh" ]; then
    SOURCE_DIR="$(dirname "$0")"
    echo "  Installing from local directory: $SOURCE_DIR"
else
    echo "  Downloading from GitHub..."
    SOURCE_DIR="$INSTALL_DIR/src"
    mkdir -p "$SOURCE_DIR"
    # TODO: Replace with actual GitHub raw URLs when published
    echo -e "${RED}  Remote install not yet available. Use --local${NC}"
    exit 1
fi

# Core scripts to install
SCRIPTS=(
    "am-prime:am-prime.sh:Session recovery and context loading"
    "am-context:am-context.sh:Rich context trails per issue"
    "am-outcome:am-outcome.sh:Outcome tracking and pattern learning"
)

for entry in "${SCRIPTS[@]}"; do
    IFS=':' read -r cmd file desc <<< "$entry"
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$INSTALL_DIR/$file"
        chmod +x "$INSTALL_DIR/$file"

        # Create symlink in bin
        ln -sf "$INSTALL_DIR/$file" "$BIN_DIR/$cmd"
        echo -e "  ${GREEN}✓${NC} $cmd - $desc"
    else
        echo -e "  ${RED}✗${NC} $file not found"
    fi
done

echo ""

# Initialize project files
echo -e "${YELLOW}Initializing AgentMem in current project...${NC}"

if [ -d ".beads" ]; then
    # Initialize context.json if not exists
    if [ ! -f ".beads/context.json" ]; then
        echo '{}' > .beads/context.json
        echo -e "  ${GREEN}✓${NC} Created .beads/context.json"
    else
        echo -e "  ${CYAN}○${NC} .beads/context.json already exists"
    fi

    # Initialize outcomes.jsonl if not exists
    if [ ! -f ".beads/outcomes.jsonl" ]; then
        touch .beads/outcomes.jsonl
        echo -e "  ${GREEN}✓${NC} Created .beads/outcomes.jsonl"
    else
        echo -e "  ${CYAN}○${NC} .beads/outcomes.jsonl already exists"
    fi

    # Create JOURNAL.md template if not exists
    if [ ! -f ".beads/JOURNAL.md" ]; then
        cat > .beads/JOURNAL.md << 'JOURNAL_EOF'
# Project Journal

> **Purpose**: Persistent notes across sessions. Read this at session start.
> **Updated**: $(date +%Y-%m-%d)

---

## User Preferences

- Add your preferences here (e.g., "ASCII diagrams only")
- Workflow preferences
- Tool preferences

---

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| Example decision | Why we chose this | 2025-01-01 |

---

## Session Notes

### $(date +%Y-%m-%d)
- Session notes go here

JOURNAL_EOF
        echo -e "  ${GREEN}✓${NC} Created .beads/JOURNAL.md template"
    else
        echo -e "  ${CYAN}○${NC} .beads/JOURNAL.md already exists"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No .beads directory found"
    echo "    Run 'bd init' first to initialize beads, then re-run this installer"
fi

echo ""

# Add to PATH instructions
echo -e "${YELLOW}Setup complete!${NC}"
echo ""

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${CYAN}Add to your shell profile (~/.bashrc or ~/.zshrc):${NC}"
    echo ""
    echo "  export PATH=\"\$PATH:$BIN_DIR\""
    echo ""
fi

echo -e "${GREEN}Available commands:${NC}"
echo "  am-prime      Load session context (run at start)"
echo "  am-context    View/add context for issues"
echo "  am-outcome    Track outcomes and patterns"
echo ""
echo -e "${CYAN}Quick start:${NC}"
echo "  1. Run 'am-prime' at session start"
echo "  2. Use 'am-context <issue> --add \"note\"' to track context"
echo "  3. Use 'am-outcome record <issue>' when closing issues"
echo ""
echo -e "${GREEN}AgentMem installed successfully! 🧠${NC}"
echo ""
