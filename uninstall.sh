#!/bin/bash
# AgentMem Uninstaller
# Cleanly removes AgentMem from your system
#
# Usage: ./uninstall.sh

set -e

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
echo -e "${CYAN}║              AgentMem Uninstaller                             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Confirm
echo -e "${YELLOW}This will remove:${NC}"
echo "  - $INSTALL_DIR (scripts)"
echo "  - $BIN_DIR/am-prime (symlink)"
echo "  - $BIN_DIR/am-context (symlink)"
echo "  - $BIN_DIR/am-outcome (symlink)"
echo ""
echo -e "${YELLOW}This will NOT remove:${NC}"
echo "  - .beads/context.json (your data)"
echo "  - .beads/outcomes.jsonl (your data)"
echo "  - .beads/JOURNAL.md (your data)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Removing symlinks...${NC}"

# Remove symlinks
for cmd in am-prime am-context am-outcome; do
    if [ -L "$BIN_DIR/$cmd" ]; then
        rm "$BIN_DIR/$cmd"
        echo -e "  ${GREEN}✓${NC} Removed $BIN_DIR/$cmd"
    elif [ -f "$BIN_DIR/$cmd" ]; then
        rm "$BIN_DIR/$cmd"
        echo -e "  ${GREEN}✓${NC} Removed $BIN_DIR/$cmd"
    else
        echo -e "  ${CYAN}○${NC} $BIN_DIR/$cmd not found (already removed?)"
    fi
done

echo ""
echo -e "${YELLOW}Removing install directory...${NC}"

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✓${NC} Removed $INSTALL_DIR"
else
    echo -e "  ${CYAN}○${NC} $INSTALL_DIR not found (already removed?)"
fi

echo ""
echo -e "${GREEN}AgentMem uninstalled successfully!${NC}"
echo ""
echo "Your data in .beads/ was preserved."
echo "To remove data too: rm .beads/context.json .beads/outcomes.jsonl .beads/JOURNAL.md"
echo ""
