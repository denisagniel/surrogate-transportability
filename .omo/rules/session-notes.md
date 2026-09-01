---
paths:
  - "session_notes/**"
---

<!-- GENERATED from .claude/rules/session-notes.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Session Notes

**Location:** `<project_root>/session_notes/` (in the repo the user is working in)
**Naming:** `YYYY-MM-DD.md` (append to today's file if it exists)
**Template:** `templates/session-note.md`

## The single session record

This is the **only** mandated session record. `quality_reports/session_logs/` was retired
2026-09-01 — see `session-logging.md`. Do not maintain a second parallel log.

### Three triggers

1. **Post-plan** — Create or append to `session_notes/YYYY-MM-DD.md`: goal, approach, key context.
2. **Incremental** — Append when a decision is made, a problem is solved, the user corrects
   something, or the approach changes. **Before compaction, append whatever is not yet written.**
3. **End-of-session** — Summary, key changes, decisions, open questions, next steps.

Several sessions share one dated file. Separate them with `## HH:MM — <stem>`, where `<stem>`
is the `YYYY-MM-DD_short-description` of the governing plan or spec when one exists (see
`canonical-paths.md`). That stem is the join key tying intent → work → learning → verification.

### Register: prose with specifics

Write what you would want to re-read in six months: what changed, in which file, and what the
numbers were. Name the bug, not its category.

> **Good** — "Inside the panel `mutate`, `A = as.integer(is.finite(group[id]))` re-indexed the
> column by `id`, scrambling treatment assignment: only ~77% of a cohort got `+tau`. Fixed to
> `is.finite(group)`; post-fix smoke test (5 reps, σ=1.0) gives DiD bias ≈ −0.07."
>
> **Not** — "Fixed a bug in the simulation. Quality: 85/100."

Optional headings, used only when they carry content: **Decisions**, **Verification**,
**Open Questions**. Omit an empty one rather than filling it in.

### Do not

- **No per-file quality-score column.** It had no reader, and it drove the verbosity that
  killed the previous session-log format.
- **No second parallel log.** One record per day per project.
- **No tables filled in for their own sake.** An empty heading is worse than no heading.

---

## Multi-Package Projects: Which session_notes/ to Use?

Multi-package projects (see `.claude/rules/multi-package-coordination.md`) have multiple session_notes/ locations:

### Structure
```
project-root/
├── session_notes/          # Root: cross-package work
├── package-a/
│   └── session_notes/      # Package A: package-specific work
└── package-b/
    └── session_notes/      # Package B: package-specific work
```

### Decision Rule

**Use package session_notes/ when:**
- Working exclusively in that package
- Changes only affect that package's code/tests/docs
- `git status` in that package shows changes, root and other packages clean

**Use root session_notes/ when:**
- Changes span multiple packages
- Cross-package coordination or integration
- Working on shared infrastructure (.claude/, meta-spec/, templates/)
- Working on manuscript/paper at root level
- Exploratory work affecting project direction

**Examples:**

| Work Type | Where to Log |
|-----------|-------------|
| Fix bug in package-a function | `package-a/session_notes/` |
| Add test to package-b | `package-b/session_notes/` |
| Breaking change in package-a that requires updating package-b | Root `session_notes/` |
| Integration testing across both packages | Root `session_notes/` |
| Update package-a + adapt all package-b callers | Root `session_notes/` |
| Write manuscript section using both packages | Root `session_notes/` |
| Design simulation comparing package-a and package-b | Root `session_notes/` |
| Add skill to .claude/skills/ | Root `session_notes/` |
| Refactor package-a internals (no external impact) | `package-a/session_notes/` |
| Update package-b vignette | `package-b/session_notes/` |

### Multi-Repo Pattern (Packages in Separate Git Repos)

**Package session_notes/ tracked in git:**
- `package-a/session_notes/` → part of package-a git repo
- `package-b/session_notes/` → part of package-b git repo

**Root session_notes/ NOT tracked in git:**
- Root is shared infrastructure, not in version control
- Or optional umbrella git repo (if you maintain one)

**Reading across locations:**
- When resuming work that spans packages, read every relevant `session_notes/` location
- One project may legitimately have several, per the decision rule above

### Monorepo Pattern (All Packages in One Git Repo)

**Single session_notes/ at root:**
- No per-package session_notes/ (unnecessary complexity)
- All work logged in root `session_notes/`
- Everything tracked in single git repo

**Rationale:** Monorepo means integrated development; cross-package changes are common, so single session_notes/ is simpler.

### When in Doubt

**Default to root session_notes/ if:**
- Uncertain which package will be affected
- Planning phase before implementation
- Might affect multiple packages
- Work has broader project implications

**Root session_notes/ captures everything; package session_notes/ are for clearly scoped work.**

### Git Status as Decision Guide

```bash
# In project root
git status

# If changes only in package-a/
# → Use package-a/session_notes/

# If changes in both package-a/ and package-b/
# → Use root session_notes/

# If changes in package-a/ and root infrastructure
# → Use root session_notes/
```

### Example Workflow

**Scenario 1: Package-specific bug fix**
```
1. cd package-a/
2. Fix bug in R/function.R
3. Update tests/testthat/test-function.R
4. git status shows only package-a/ changes
5. Update package-a/session_notes/YYYY-MM-DD.md
6. git commit (package-a repo)
```

**Scenario 2: Cross-package breaking change**
```
1. Plan in quality_reports/plans/ (root)
2. Update root session_notes/ (post-plan)
3. Implement change in package-a/
4. git commit (package-a repo)
5. Update package-b/ to use new API
6. Test integration
7. git commit (package-b repo)
8. Update root session_notes/ (end-of-session summary)
```

---

## See Also

- `.claude/rules/multi-package-coordination.md` - Full multi-package guidance
- `.claude/rules/session-logging.md` - Retirement notice for the former parallel session log
- `.claude/rules/canonical-paths.md` - Stem-pairing convention for the `## HH:MM — <stem>` heading
- `meta-spec/EXAMPLE_PROJECTS.md` - Project structure examples
