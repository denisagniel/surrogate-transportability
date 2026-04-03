---
paths:
  - "**/*"
---

# Canonical Path Structure

**Purpose:** Enforce consistent directory structure across projects to reduce cognitive load and improve tooling predictability.

**Principle:** "Convention over configuration with escape hatches" — one canonical path per purpose, with documented exceptions allowed.

---

## Quick Reference

| Purpose | Canonical Path | Deprecated Alternatives |
|---------|----------------|------------------------|
| R package code | `R/` | ❌ None (package standard) |
| Package tests | `tests/testthat/` | ❌ None (package standard) |
| Paper (in package) | `inst/paper/` | ❌ `paper/`, `latex/`, `manuscript/` |
| Paper (no package) | `manuscript/` | ❌ `latex/`, `paper/` |
| Analysis scripts (no package) | `analysis/` | ❌ `scripts/`, `R/` |
| Simulations (package project) | `simulations/` | ❌ `scripts/`, `inst/simulations/` |
| Grant proposal | `proposal/` | ❌ `grant/` |
| Session notes (single project) | `session_notes/` | ❌ None |
| Session notes (multi-package) | `session_notes/` (root only) | ❌ Per-package session notes |
| Quality reports | `quality_reports/` | ❌ None (location fixed) |

---

## Canonical Structures by Project Type

### 1. Single R Package (No Paper)

```
package-name/
├── .git/
├── .claude/                    # Required
├── meta-spec/                  # Required
├── CLAUDE.md                   # Required
├── MEMORY.md                   # Required
├── session_notes/              # Required
├── quality_reports/            # Required
│   ├── plans/
│   └── session_logs/
├── DESCRIPTION                 # Package metadata
├── NAMESPACE                   # Exports
├── R/                          # Required: Package code
├── tests/                      # Required: testthat tests
│   └── testthat/
├── man/                        # Generated: roxygen2 docs
├── vignettes/                  # Recommended
├── data/                       # If data package
└── inst/                       # For installed files
```

**Rules:**
- ✅ R code MUST be in `R/`
- ✅ Tests MUST be in `tests/testthat/`
- ❌ NO `scripts/` at root (use `inst/scripts/` if needed)
- ❌ NO temporary test files at root (`test_*.R`, `test_*.Rout`)

---

### 2. R Package + Paper

```
package-name/
├── .git/
├── (core folders as above)
├── R/                          # Required
├── tests/                      # Required
├── inst/
│   └── paper/                  # Canonical: Paper location
│       ├── manuscript.tex
│       ├── bibliography.bib
│       └── figures/
├── simulations/                # Canonical: Root level
│   ├── dgps.R
│   ├── run_simulations.R
│   └── figures/
└── vignettes/
```

**Rules:**
- ✅ Paper MUST be in `inst/paper/` (travels with package)
- ✅ Simulations MUST be at root `simulations/` (separate from package code)
- ❌ NO `scripts/` for simulations (use `simulations/`)
- ❌ NO `paper/` at root (use `inst/paper/`)

**Exception:** If paper uses package + other packages (not tightly coupled), use separate repo pattern.

---

### 3. Applied Paper / No Package

```
project-name/
├── .git/
├── (core folders)
├── manuscript/                 # Canonical: Not latex/, not paper/
│   ├── main.tex
│   ├── sections/
│   ├── bibliography.bib
│   └── figures/                # Copies for LaTeX
├── analysis/                   # Canonical: Not scripts/, not R/
│   ├── 01-data-prep.R
│   ├── 02-descriptives.R
│   ├── 03-main-analysis.R
│   └── 04-figures.R
├── data/
│   ├── raw/
│   └── processed/
└── output/                     # Generated artifacts
    ├── tables/
    └── figures/                # Original figures
```

**Rules:**
- ✅ Manuscript MUST be in `manuscript/` (not `latex/`, not `paper/`)
- ✅ Analysis MUST be in `analysis/` (not `scripts/`, not `R/`)
- ✅ Figures generated to `output/figures/`, copied to `manuscript/figures/`
- ✅ Analysis scripts MUST be numbered (01-, 02-, 03-)
- ❌ NO mixing manuscript source with output

**Rationale:**
- `manuscript/` is clearer than generic `latex/` or `paper/`
- `analysis/` distinguishes from package-style `R/` and generic `scripts/`
- Numbered scripts enforce reproducible execution order

---

### 4. Multi-Package (Multi-Repo)

```
project-name/                   # Root (not in git)
├── .claude/                    # Shared
├── meta-spec/                  # Shared
├── quality_reports/            # Shared (plans + logs)
├── session_notes/              # Root-level ONLY (not per-package)
├── package-a/                  # Independent git
│   ├── .git/
│   ├── R/
│   └── tests/
└── package-b/                  # Independent git
    ├── .git/
    ├── R/
    ├── tests/
    └── inst/
        └── paper/              # If paper presents package B
```

**Rules:**
- ✅ Root `session_notes/` ONLY (no per-package session notes)
- ✅ Root `quality_reports/` ONLY (plans coordinate packages)
- ✅ Paper location: Use decision tree (see PATH_STRUCTURE_DECISIONS.md)
- ✅ Each package follows single-package rules internally
- ❌ NO duplicate session notes at multiple levels (creates redundancy)

**Rationale:** Eliminates 3-tier session notes redundancy (root + package-a + package-b). Cross-package coordination happens at root level.

---

### 5. Multi-Package (Monorepo)

```
project-name/                   # Single git repo
├── .git/
├── (core folders)
├── session_notes/              # Single location
├── quality_reports/            # Single location
├── manuscript/                 # If paper presents both
│   └── ...
├── package-core/
│   ├── R/
│   └── tests/
└── package-methods/
    ├── R/
    └── tests/
```

**Rules:**
- ✅ Single `session_notes/` at root
- ✅ Single `quality_reports/` at root
- ✅ Paper at root `manuscript/` if presents both packages
- ❌ NO per-package session notes or quality reports

---

### 6. Grant Proposal

```
grant-name/
├── .git/
├── (core folders)
├── proposal/                   # Canonical
│   ├── specific-aims.tex
│   ├── significance.tex
│   ├── innovation.tex
│   ├── approach.tex
│   ├── bibliography.bib
│   └── figures/
├── preliminary/                # Analysis for prelim data
│   ├── analysis.R
│   └── figures/
└── budget/                     # Budget justification
    └── budget-justification.tex
```

**Rules:**
- ✅ Proposal text MUST be in `proposal/`
- ✅ Preliminary analysis MUST be in `preliminary/`
- ❌ NO `grant/` (use `proposal/`)
- ❌ NO mixing proposal and analysis at root

---

## When to Deviate

**Allowed exceptions:**

1. **Legacy projects (pre-2026-04-01):** No forced migration. Migrate when convenient or when causing issues.

2. **External constraints:**
   - Journal requires specific structure (e.g., JASA template with fixed paths)
   - Collaboration with external repository structure
   - Institutional requirements

3. **Tightly integrated workflows:**
   - Quarto book with custom structure
   - Complex build systems with path dependencies
   - Multi-language projects with language-specific conventions

4. **Package conventions override:**
   - R packages MUST use `R/`, `tests/`, `vignettes/`, `inst/`, `data/` per CRAN
   - Python packages MUST use language conventions
   - Other ecosystems follow their standards

**Document deviations** in project CLAUDE.md with rationale:

```markdown
## Path Structure Deviations

**Non-canonical paths:**
- Using `latex/` instead of `manuscript/` (journal template requirement)
- Using `scripts/` instead of `analysis/` (legacy project, 2+ years old)

**Rationale:** [Explain why deviation necessary]
```

---

## Validation

**Check conformance:**
```bash
./scripts/validate-structure.sh
```

Script detects project type from CLAUDE.md and validates canonical paths are used. Emits:
- **Warnings:** Non-canonical but workable paths (exit 0)
- **Errors:** Problematic paths that violate conventions (exit 1)

---

## Migration

**For non-conforming projects:**
```bash
./scripts/migrate-canonical-paths.sh [project-path]
```

Script:
1. Detects current structure
2. Proposes migration plan
3. Creates backup
4. Executes migrations with user approval
5. Updates references in files

**Common migrations:**
- `latex/` → `manuscript/`
- `scripts/` → `analysis/` (if not a package)
- `paper/` → `inst/paper/` (if package) or `manuscript/` (if not)
- Remove per-package session notes (multi-package projects)

---

## Benefits of Canonical Paths

1. **Reduced cognitive load:** One obvious path per purpose
2. **Predictable tooling:** Path-conditional rules (`paths:` frontmatter) work consistently
3. **Easier onboarding:** New users see consistent structure across projects
4. **Clearer templates:** One structure to show, not variations
5. **Simplified validation:** Check canonical paths, warn on deviations
6. **Better search:** Know where to find things across projects

---

## Common Questions

### Q: Can I still use `latex/` for my manuscript?

**A:** Yes, but `manuscript/` is canonical going forward.

**Migration:** Not urgent for existing projects. New projects should use `manuscript/`. When convenient, migrate using `scripts/migrate-canonical-paths.sh`.

### Q: Why `analysis/` instead of `scripts/`?

**A:**
- `scripts/` is generic (could be build scripts, data scripts, etc.)
- `analysis/` is specific to statistical analysis
- Distinguishes from package code (`R/`) and package scripts (`inst/scripts/`)

### Q: What if I have both a package and standalone scripts?

**A:**
- Package code → `R/`
- Package tests → `tests/`
- Simulations using package → `simulations/` (root level)
- Helper scripts → `inst/scripts/` (installed with package)

### Q: Where do simulations go in a package project?

**A:** Root `simulations/`, not `inst/simulations/` or mixed with `R/`.

**Rationale:** Simulations are separate from package code (not installed with package), but use the package.

### Q: What about multi-package projects?

**A:** Session notes at root ONLY. No per-package session notes (eliminates redundancy).

**See:** `.claude/rules/multi-package-coordination.md` for coordination guidance.

---

## See Also

- `meta-spec/PATH_STRUCTURE_DECISIONS.md` - Decision tree for path choices
- `meta-spec/EXAMPLE_PROJECTS.md` - Canonical examples for each pattern
- `scripts/validate-structure.sh` - Validation tool
- `scripts/migrate-canonical-paths.sh` - Migration automation
- `templates/project-types/` - Project templates using canonical paths

---

## Version History

- **2026-04-02:** Initial canonical path structure enforcement
