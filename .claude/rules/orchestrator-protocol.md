# Orchestrator Protocol: Contractor Mode

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
