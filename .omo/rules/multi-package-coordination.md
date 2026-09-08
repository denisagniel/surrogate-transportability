---
paths:
  - "**/DESCRIPTION"
  - "**/.Rbuildignore"
  - "**/session_notes/**"
---

<!-- GENERATED from .claude/rules/multi-package-coordination.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Multi-Package Project Coordination

**When this applies:** Projects with 2+ R packages (or other software components) that need coordinated development, shared infrastructure, or cross-package dependencies.

**Example:** global-scholars has `optimaltrees/` (core trees) + `doubletree/` (inference) + shared manuscript in `doubletree/paper/`.

---

## Three Coordination Patterns

### Pattern 1: Multi-Repo (Recommended for Published Packages)

**Structure:**
```
project-root/
├── .claude/              # Shared workflow infrastructure (not in git)
├── meta-spec/            # Shared research constitution (not in git)
├── templates/            # Shared templates (not in git)
├── quality_reports/      # Cross-package plans/logs (not in git)
├── session_notes/        # Cross-package work logs (not in git)
│
├── package-a/            # Separate git repo
│   ├── .git/
│   ├── R/
│   ├── tests/
│   ├── session_notes/    # Package-specific logs (in git)
│   └── DESCRIPTION
│
└── package-b/            # Separate git repo
    ├── .git/
    ├── R/
    ├── tests/
    ├── session_notes/    # Package-specific logs (in git)
    └── DESCRIPTION
```

**When to use:**
- Packages will be published separately (CRAN, GitHub releases)
- Different release cycles
- Different contributors/maintainers
- Packages have independent value

**Version control:**
- Each package: independent git repo, own remotes, own versioning
- Root level: shared infrastructure not in git (or optional umbrella repo)

**Pros:** Independent releases, clear boundaries, standard package structure
**Cons:** Must manually coordinate breaking changes across packages

---

### Pattern 2: Monorepo (Recommended for Tightly Coupled Development)

**Structure:**
```
project-root/              # Single git repo
├── .git/
├── .claude/
├── meta-spec/
├── quality_reports/
├── session_notes/         # All work logs here
│
├── package-a/             # Subdirectory in monorepo
│   ├── R/
│   ├── tests/
│   └── DESCRIPTION
│
└── package-b/             # Subdirectory in monorepo
    ├── R/
    ├── tests/
    └── DESCRIPTION
```

**When to use:**
- Packages always released together
- Frequent cross-package refactoring
- Single logical project with multiple components
- Packages don't have independent value

**Version control:**
- Single git repo at root
- Commit changes across packages atomically
- Shared version numbers or synchronized versioning

**Pros:** Atomic commits across packages, simpler coordination
**Cons:** Can't version/release independently, harder to publish separately

---

### Pattern 3: Hybrid (Development Monorepo → Published Multi-Repo)

Develop in monorepo, then split into separate repos for publication. Not recommended unless you have automation for the split.

---

## Session Notes Strategy

### Multi-Repo Pattern

**Package-specific work:**
- Log in `package-a/session_notes/YYYY-MM-DD.md`
- Tracked in package git repo
- Use when: working on package internals, writing tests, bug fixes

**Cross-package work:**
- Log in root `session_notes/YYYY-MM-DD.md`
- Not tracked in git (shared infrastructure)
- Use when: coordinating versions, cross-package refactoring, integration testing

**Decision rule:** If `git status` shows changes in only one package, use that package's session notes. If changes span multiple packages or root infrastructure, use root session notes.

### Monorepo Pattern

**All work:**
- Single `session_notes/` at root
- Tracked in git (everything is in the repo)

---

## Quality Reports Location

**Multi-repo:** Root `quality_reports/` for all work (package-specific or cross-package)
**Monorepo:** Root `quality_reports/` (only one location exists)

Plans and session logs track work across the project, regardless of package boundaries.

---

## Cross-Package Dependencies

### If Package B Depends on Package A

**During development:**
```r
# In package-b/DESCRIPTION
Remotes: github::username/package-a

# Or use local installation
remotes::install_local("../package-a")
```

**Testing integration:**
- Install Package A → run Package B tests
- Automate with script or CI

**Version pinning:**
```r
# In package-b/DESCRIPTION
Imports:
    packageA (>= 0.4.0)
```

**Breaking changes:**
- Plan together (root `quality_reports/plans/`)
- Implement in Package A
- Update Package B in same session
- Test integration before committing

---

## Git Workflow Patterns

### Multi-Repo: Coordinated Commits

**Scenario:** Breaking change in Package A affects Package B

**Protocol:**
1. Branch in Package A: `feature/new-api`
2. Branch in Package B: `feature/adapt-to-new-api`
3. Develop both in parallel
4. Test integration (install A from branch, run B tests)
5. Merge Package A first
6. Merge Package B (now depends on merged A)

**Git commands:**
```bash
# In package-a/
git checkout -b feature/new-api
# ... make changes ...
git commit -m "Breaking: Change API signature"
git push origin feature/new-api

# In package-b/
git checkout -b feature/adapt-to-new-api
# ... adapt to new API ...
remotes::install_github("username/package-a@feature/new-api")
# ... test ...
git commit -m "Adapt to package-a new API"
git push origin feature/adapt-to-new-api

# Merge A first, then B
```

### Multi-Repo: Package-Specific Commits

**Scenario:** Bug fix in Package A, no changes to Package B

**Protocol:**
1. Work in Package A directory
2. Commit to Package A git repo
3. Update Package A's `session_notes/`
4. No action needed for Package B

**Git commands:**
```bash
# In package-a/
git status  # Only shows package-a changes
git add R/function.R tests/testthat/test-function.R
git commit -m "Fix edge case in function"
git push
```

### Monorepo: Atomic Commits

**Scenario:** Breaking change spans both packages

**Protocol:**
1. Make changes in both package directories
2. Single commit captures both
3. Update root `session_notes/`

**Git commands:**
```bash
# At project root
git status  # Shows changes in both packages
git add package-a/R/function.R package-b/R/caller.R
git commit -m "Breaking: Change API and update all callers"
git push
```

---

## When to Use Root vs Package Directories

| Activity | Multi-Repo | Monorepo |
|----------|-----------|----------|
| Implement package function | Work in package dir | Work in package dir |
| Write package tests | Work in package dir | Work in package dir |
| Package documentation | Work in package dir | Work in package dir |
| Cross-package integration test | Root or either package | Root or either package |
| Shared manuscript/paper | Root or package dir | Root or package dir |
| Infrastructure (.claude/, meta-spec/) | Root | Root |

**Rule of thumb:** Work in the lowest directory that contains all files you need to modify.

---

## Quality Gates

**Package-specific changes:**
- Run `devtools::test()` in that package
- Run `R CMD check` before committing (package quality)
- Package must pass quality gates (≥80 for commit)

**Cross-package changes:**
- Test both packages
- Verify integration (Package B still works with new Package A)
- Coordinate commits (A before B in multi-repo)

---

## Multi-Package Code Review

When invoking `/review-r` or r-reviewer agent:

**Specify scope:**
- "Review package-a only" → focuses on that package
- "Review cross-package changes" → considers both packages
- "Review integration" → checks if B correctly uses A's new API

**Multi-package simulation review:**
- `/review-simulations` should verify code-paper-package alignment across all packages
- Check that DGPs match paper, packages match paper claims

---

## Common Pitfalls

[PITFALL:multi-package] Committing Package B changes before Package A changes are merged breaks B's build (it depends on unreleased A).

[PITFALL:multi-package] Using `package-a/session_notes/` for work that touches package B loses context about cross-package coordination.

[PITFALL:multi-package] Not testing integration after updating Package A causes Package B breakage discovered late.

[PITFALL:multi-package] Forgetting to update Package B's `DESCRIPTION` Imports version after breaking change in Package A allows incompatible versions.

---

## Template

Use `templates/project-types/multi-package-methods.md` for starting new multi-package methods projects.

---

## Real Example: global-scholars

**Pattern:** Multi-repo
- `optimaltrees/` - Core tree-building package (v0.4.0, published on GitHub)
- `doubletree/` - EIF-based inference package (v0.0.0.9000, depends on optimaltrees)
- Manuscript lives in `doubletree/paper/` (makes sense: paper presents inference, which is doubletree's focus)

**Session notes:**
- `optimaltrees/session_notes/` - Tree algorithm development
- `doubletree/session_notes/` - Inference method development
- Root `session_notes/` - Cross-package work, paper writing, simulations comparing the two

**Dependency:** doubletree Imports optimaltrees. Breaking changes in optimaltrees require coordinated updates.

**Quality reports:** Root `quality_reports/` tracks all work (both packages, paper, simulations).
