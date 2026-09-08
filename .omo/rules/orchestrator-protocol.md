---
paths:
  - "R/**"
  - "**/*.py"
  - "**/*.tex"
  - "**/*.qmd"
  - "slides/**"
---

<!-- GENERATED from .claude/rules/orchestrator-protocol.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Orchestrator Protocol: Contractor Mode

> **Which orchestrator?** Use **this** (full multi-agent verify→review→fix loop) for heavier deliverables: R **packages** (`R/**`), papers/LaTeX, slides, Python. For standalone R scripts, simulations, data analysis, and `explorations/`, run a **reduced form of this same loop**: one verification pass plus the `r-code-conventions.md` §9 checklist and the `quality-gates.md` thresholds, skipping the multi-agent review fan-out. (This replaces the former `orchestrator-research.md`, archived 2026-08-13 — see `archive/rules/`.)

**After a plan is approved, the orchestrator takes over autonomously.**

## The Loop

```
Plan approved → orchestrator activates
  │
  Step 1: IMPLEMENT — Execute plan steps
  │
  Step 2: VERIFY — Compile, render, check outputs
  │         If verification fails → fix → re-verify
  │
  Step 3: REVIEW — Run review agents (by file type)
  │
  Step 4: FIX — Apply fixes (critical → major → minor)
  │
  Step 5: RE-VERIFY — Confirm fixes are clean
  │
  Step 6: SCORE — Apply quality-gates rubric
  │
  └── Score >= threshold?
        YES → Present summary to user
        NO  → Loop back to Step 3 (max 5 rounds)
              After max rounds → present with remaining issues
```

## Limits

- **Main loop:** max 5 review-fix rounds
- **Critic-fixer sub-loop:** max 5 rounds
- **Verification retries:** max 2 attempts
- Never loop indefinitely

**Why multiple review-fix rounds?** This supports the "correctness over speed" principle (`.claude/rules/quality-philosophy.md`). Taking time to get things right through iterative review is faster than shipping bugs and fixing them later.

## Subagent Health Gate

**A returned result is not evidence of success, and silence is not evidence of anything.** Before Step 6 (SCORE) or presenting any summary that depends on delegated work, check every session you dispatched:

```
scripts/check-subagent-health.sh ses_ID [ses_ID ...]
```

| Verdict | Meaning | Required action |
|---|---|---|
| `ERRORED` | provider/process error logged for that session | Output is untrustworthy. Re-dispatch, or state the failure explicitly. Never fold it into a summary as if it succeeded. |
| `NO-ACTIVITY` | session exists, never streamed | Same as ERRORED. |
| `MISSING` | no log entries at all | Not proof of success. The session may belong to another project directory, or never started. |
| `CHECK` | advisory — long stream silence before termination | Confirm the returned result is non-empty and on-topic. Ambiguous by construction (see below). |
| `HEALTHY` | clean run | Proceed. |

**Why this gate exists.** On 2026-08-27 four `proof-writer` subagents were dispatched from one parent session. One died after 43 minutes on a Bedrock request-validation error; another stalled and was cancelled with no error record. Both were reported upstream as "no response" and then misdiagnosed for an hour as a tool-permission problem. The first failure **was written to the log as `level=ERROR` and simply never read.** The signal existed; nothing consumed it.

**Two limits, stated so they are not mistaken for bugs:**

- `CHECK` cannot distinguish a stall from a long final generation. Measured on the same day: a wedged session showed 355s of pre-termination silence, a fully successful one 303s. Proving the difference requires the on-disk message store (last assistant parts, `finishReason`), which the script deliberately does not parse.
- Do **not** tighten `STALE_WARN_SEC` below ~180. A healthy proof-writer run had legitimate inter-step gaps of 2m15s under host load, and a tighter threshold flags it.

**Dispatch scope.** Prefer one deliverable per subagent invocation. The 43-minute failure was the one invocation carrying a combined multi-item task; the three narrow ones dispatched minutes later on the same model survived. Failure probability for that error class grows with turn count, so scope is a mitigation, not just a style preference.

## "Just Do It" Mode

When user says "just do it" / "handle it":
- Skip final approval pause
- Auto-commit if score >= 80
- Still run the full verify-review-fix loop
- Still present the summary

---

## Parallel Workflow: Multiple Tasks Simultaneously

**Principle:** Run multiple Claude sessions in parallel using git worktrees to maximize throughput. Based on Boris Cherny (Claude Code creator) productivity patterns.

### When to Work in Parallel

Use parallel sessions when you have:
- **Independent tasks** that don't affect the same files
- **Multiple projects** needing attention
- **Long-running operations** (simulations, literature reviews) that can proceed while you work on something else
- **Exploratory work** on one branch while maintaining stable work on another

### Git Worktree Setup

#### Create a Worktree
```bash
# Create worktree for feature work
git worktree add ../project-feature-branch feature-branch

# Create worktree for exploration
git worktree add ../project-exploration -b exploration-branch
```

#### Launch Parallel Sessions
- **Session 1:** Main working directory (main or development branch)
- **Session 2:** Worktree 1 (feature branch)
- **Session 3:** Worktree 2 (exploration branch)

Each session has:
- Its own git checkout (no conflicts)
- Independent Claude context
- Separate file state

#### Cleanup After Completion
```bash
# From main working directory
git worktree remove ../project-feature-branch
git branch -d feature-branch  # If no longer needed
```

### Parallel Session Patterns

#### Pattern 1: Main + Feature
- **Session A (main):** Continue daily work, reviews, small fixes
- **Session B (worktree):** Develop new feature requiring significant changes

#### Pattern 2: Multiple Features
- **Session A (worktree-1):** Implement feature X
- **Session B (worktree-2):** Implement feature Y
- Merge when both complete

#### Pattern 3: Stable + Exploration
- **Session A (main):** Paper writing, stable manuscript work
- **Session B (worktree):** Experimental simulation designs in `explorations/`

#### Pattern 4: Long-Running + Active Work
- **Session A (background):** Run simulations, literature review, data processing
- **Session B (active):** Continue with other work
- **Session A** notifies when complete (or check periodically)

### Context Management Across Sessions

**Each session maintains independent:**
- MEMORY.md (session-specific learning)
- Session logs
- Plan documents
- Active task context

**Shared across sessions:**
- Git repository (different branches/commits)
- `.claude/` configuration (skills, rules, agents)
- `meta-spec/` (research constitution, project types)

### Best Practices

1. **Name worktrees descriptively** - Use branch names that indicate purpose
2. **One task per worktree** - Keep sessions focused on single goals
3. **Merge frequently** - Don't let branches diverge too far
4. **Clean up completed worktrees** - Remove after merging
5. **Use session notes** - Each session updates its own `session_notes/YYYY-MM-DD.md`
6. **Coordinate merges** - Use quality gates before merging each branch

### Coordination Strategy

When running parallel sessions:
- **Plan in session A** → Execute in session A
- **Plan in session B** → Execute in session B
- **Don't mix contexts** between sessions (leads to confusion)
- **Commit often** in each session to avoid conflicts
- **Merge one at a time** - Complete session A → merge → then session B → merge

### Example Workflow

```bash
# In project root (Session A: paper writing)
# Working on manuscript

# Create worktree for simulation study (Session B)
git worktree add ../project-simulations simulation-study
cd ../project-simulations

# Launch Claude in new terminal/window
# Session B works on simulation study independently

# When simulation study complete:
cd ../project  # Back to Session A location
git merge simulation-study
git worktree remove ../project-simulations
```

### Limitations

**Don't use parallel sessions when:**
- Tasks affect the same files (will create merge conflicts)
- Tasks have dependencies (one needs output from the other)
- You need context from both tasks simultaneously
- The cognitive overhead of switching exceeds the parallelism benefit

**Use subagents instead** for parallel work within a single session (orchestrator spawning multiple agents).

### Throughput Gains

Parallel sessions can provide:
- **2-3x throughput** for independent tasks
- **Background processing** while you focus on active work
- **Reduced context switching** (each session maintains focus)
- **Faster iteration** on multiple projects/features

This is distinct from the orchestrator's use of subagents (parallel agents within one session) - this is about parallel Claude sessions across different branches/worktrees.
