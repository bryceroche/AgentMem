# Draft Issue for steveyegge/beads

**Status:** READY TO SEND (externally validated)

---

**Title:** `[Discussion] AgentMem - Project memory layer for beads`

**Body:**

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
- Outcome stats (success rates, patterns by approach)
- In-progress and open issues

These follow your EXTENDING.md pattern - they read from beads.db but write to separate JSON files.

## External Validation

I tested this with another AI (Cursor's default) on a fresh machine. Their assessment:

> "The tools are well-designed and solve a real problem. The integration between beads (issue tracking) and AgentMem (memory layer) is elegant."

Key feedback:
- Context persistence is the biggest win
- Structured context (notes, findings, decisions) is "brilliant"
- Outcome learning by approach could lead to real insights

## Questions

1. Is this complementary to beads, or scope creep?
2. Would you want this in `integrations/agentmem/` or as a standalone repo?
3. Any feedback on the approach?

Repo: https://github.com/bryceroche/AgentMem

Thanks for building beads - it's been a game changer!

---

## Where to Post

GitHub Issue: https://github.com/steveyegge/beads/issues/new

Or GitHub Discussions if they prefer that for proposals.
