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

AgentMem provides six core tools:

| Command | Purpose |
|---------|---------|
| `am-prime` | Load all context at session start |
| `am-context` | Track decisions, findings, and notes per issue |
| `am-outcome` | Record what worked/didn't for emergent learning |
| `am-journal` | Interactive journal setup with templates |
| `am-stats` | Visualize outcomes with ASCII charts |
| `am-search` | Enhanced search with fuzzy matching |

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
- **AI Context Triggers** - Guidance for when to record decisions, findings, and outcomes

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

### am-journal
Interactive journal setup and management.

```bash
# Interactive setup (prompts for project name and template)
am-journal init

# Use a specific template
am-journal init --template consulting

# Quick additions
am-journal add-pref "ASCII diagrams only"
am-journal add-decision "Use PostgreSQL" "Better for our scale"
am-journal add-note "Completed API refactor"

# View current journal
am-journal show
```

**Templates:**
- `minimal` - Just preferences and decisions
- `standard` - Good for most projects
- `consulting` - For client work (+ background, deliverables)
- `oss` - For open source (+ roadmap, contributing)

### am-stats
Visualize outcomes with ASCII charts.

```bash
# Full dashboard
am-stats

# Individual views
am-stats summary          # Quick stats
am-stats approaches       # Success rate by approach (bar chart)
am-stats complexity       # Success rate by complexity
am-stats timeline         # Outcomes over time (last 14 days)
am-stats streak           # Current success/failure streak
```

**Example output:**
```
📈 SUCCESS RATE BY APPROACH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  implement-iterate    █████████████████████████ 12/12 (100%)
  research-first       ██████░░░░░░░░░░░░░░░░░░░ 3/3 (100%)
  collaborative        ██████░░░░░░░░░░░░░░░░░░░ 3/3 (100%)

🔥 CURRENT STREAK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎉 20 successful in a row!
  🏆 Best ever: 20 successes
```

### am-search
Enhanced search with fuzzy matching and ranked results.

```bash
# Basic search
am-search postgres

# Multi-term (AND by default)
am-search database migration

# OR logic
am-search --or redis postgres

# Fuzzy matching (finds similar words)
am-search --fuzzy postgre

# Filter by type
am-search --type decision approach
am-search --type finding api
```

**Features:**
- Fuzzy matching with `--fuzzy`
- Multi-term AND/OR search
- Type filtering (note, finding, decision, outcome)
- Ranked results (most relevant first)
- Searches context, outcomes, and issue titles

## AI Auto-Context

AgentMem helps AI agents know when to record context by including **AI Context Triggers** in the `am-prime` output. When an agent reads this at session start, it learns:

**Record a DECISION when:**
- Choosing between approaches
- Making architecture choices
- Picking a library or tool

**Record a FINDING when:**
- Discovering how existing code works
- Finding undocumented behavior
- Learning something that took effort

**Record an OUTCOME when:**
- Closing an issue (success or failure)
- Completing a task

This "soft hook" approach embeds guidance directly in the session context, so agents naturally follow best practices without requiring explicit tool integration.

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
