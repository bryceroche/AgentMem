# Draft Issue for steveyegge/beads

**Status:** DRAFT - VERIFIED

---

## Verification Results ✅

| Claim | Beads Native? | AgentMem Adds? |
|-------|---------------|----------------|
| Workflow context (commands, rules) | ✅ `bd prime` | ❌ Not needed |
| User preferences (e.g., "ASCII only") | ❌ No | ✅ JOURNAL.md |
| Decision rationale per issue | ❌ No | ✅ context.json |
| Findings/discoveries per issue | ❌ No | ✅ context.json |
| Outcome tracking (success/fail) | ❌ No | ✅ outcomes.jsonl |
| Pattern learning from outcomes | ❌ No | ✅ am-outcome stats |
| Open/in-progress issues | ✅ `bd ready`, `bd list` | ✅ Also shows |
| Recent file changes | ❌ No | ✅ Shows in am-prime |

### Key Difference

**`bd prime`** = "How to use beads" (commands, workflow rules, git protocol)
**`am-prime`** = "What happened in this project" (preferences, decisions, outcomes, context)

They're **complementary**, not overlapping.

---

## Updated Draft Issue

**Title:** `[Discussion] AgentMem - Project memory layer for beads`

**Body:**
```markdown
Hi Steve,

I've been using beads for a few weeks and love `bd prime` for workflow context. I built some complementary scripts that add **project-specific memory** - the stuff that's unique to each project rather than universal beads workflow.

## What bd prime does well
- Workflow commands and rules
- Git sync protocol
- Session close checklist

## What I kept forgetting between sessions
- User preferences ("ASCII diagrams only", "wife reviews architecture docs")
- Why I made specific decisions on issues
- What approaches worked/failed on past issues
- Rich context beyond issue title/description

## What I built (3 bash scripts)

| Command | Purpose | Storage |
|---------|---------|---------|
| `am-prime` | Load project context at session start | Reads .beads/*.json |
| `am-context` | Track findings/decisions/notes per issue | .beads/context.json |
| `am-outcome` | Record success/failure + approach when closing | .beads/outcomes.jsonl |

Example `am-prime` output shows:
- User preferences from JOURNAL.md
- Recent decisions with rationale
- Outcome stats (20/20 successful, patterns by approach)
- In-progress and open issues

These follow your EXTENDING.md pattern - they read from beads.db but write to separate JSON files.

## Questions

1. Is this complementary to beads, or scope creep?
2. Would you want this in `integrations/agentmem/` or as a standalone repo?
3. Any feedback on the approach?

Repo: https://github.com/bryceroche/AgentMem (will push code soon)

Thanks for building beads - it's been a game changer!
```

---

## Honest Assessment

**Real value add:**
- Per-issue context (decisions, findings) - beads doesn't have this
- Outcome tracking with approach patterns - beads doesn't have this
- User preferences in JOURNAL.md - beads doesn't have this

**Overlap:**
- Both show open/in-progress issues (but am-prime adds more context)

**Conclusion:** This is a legitimate extension, not reinventing the wheel. The core value is **per-issue rich context** and **outcome learning**, which beads explicitly doesn't do.
