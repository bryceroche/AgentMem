# AgentMem

**Memory layer for AI coding agents.**

AI coding assistants (Claude Code, Cursor, Copilot) lose context between sessions. AgentMem fixes this by providing persistent memory, outcome tracking, and session recovery.

## The Problem

```
Session 1: "Let's use approach X because Y"
[session ends]
Session 2: "Why did we choose X again?"
[agent doesn't know, makes different decision]
```

## The Solution

AgentMem provides three core tools:

| Command | Purpose |
|---------|---------|
| `am-prime` | Load all context at session start |
| `am-context` | Track decisions, findings, and notes per issue |
| `am-outcome` | Record what worked/didn't for emergent learning |

## Quick Start

```bash
# Install (requires beads: https://github.com/steveyegge/beads)
./install.sh --local

# Add to your PATH
export PATH="$PATH:$HOME/.local/bin"

# At session start
am-prime

# Track context as you work
am-context <issue-id> --add-decision "Use X" --why "Because Y"
am-context <issue-id> --add-finding "Discovered Z" --confidence high

# When closing issues
am-outcome record <issue-id> --success
```

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE AGENT MEMORY LAYER                        │
│                                                                  │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│   │   CONTEXT   │ -> │   OUTCOMES  │ -> │   JOURNAL   │         │
│   │  (per task) │    │ (patterns)  │    │ (prefs)     │         │
│   └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                          │                                       │
│                    am-prime (session recovery)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Context (per issue)
- **Notes**: Free-form observations
- **Findings**: Discoveries with source and confidence
- **Decisions**: What was decided and why
- **Tags**: Categorization for search
- **Related**: Links between issues

### Outcomes (aggregate learning)
- Success/failure rate by approach
- Duration tracking
- Pattern recognition over time

### Journal (global preferences)
- User preferences (e.g., "ASCII diagrams only")
- Key decisions
- Session notes

## Commands Reference

### am-prime
Load session context. Run at start of every session.

```bash
am-prime
```

Output includes:
- User preferences from journal
- Recent context entries (last 7 days)
- Outcome statistics
- Open/in-progress issues
- Recently modified files

### am-context
Rich context trails per issue.

```bash
# View all context
am-context <issue>

# Add different types
am-context <issue> --add "Simple note"
am-context <issue> --add-finding "Discovery" --source "code review" --confidence high
am-context <issue> --add-decision "Choice" --why "Reason" --alternatives "A,B,C"
am-context <issue> --add-tag "tag1,tag2"
am-context <issue> --link "related-issue"

# Search across all context
am-context --search "keyword"
am-context --tag "tagname"
am-context --list
```

### am-outcome
Track and learn from completed work.

```bash
# Record outcome when closing
am-outcome record <issue> --success --approach "implement-iterate"
am-outcome record <issue> --failure --approach "big-bang"

# View statistics
am-outcome stats
am-outcome stats --by-approach
am-outcome recent 5
```

## Requirements

- **beads** - Issue tracker for agents ([install](https://github.com/steveyegge/beads))
- **python3** - For JSON processing
- **sqlite3** - For beads database queries

## File Structure

AgentMem uses beads' `.beads/` directory:

```
.beads/
├── beads.db          # Beads database (read-only)
├── context.json      # AgentMem context data
├── outcomes.jsonl    # AgentMem outcome data
└── JOURNAL.md        # User preferences and notes
```

## Why "AgentMem"?

This project was inspired by [arXiv:2512.03560](https://arxiv.org/abs/2512.03560) (RP-ReAct), which shows that decoupling planning from execution improves AI agent reliability. AgentMem provides the memory layer that makes this possible.

## License

MIT

## Contributing

PRs welcome! This started as extensions to [beads](https://github.com/steveyegge/beads) and may be contributed upstream.
