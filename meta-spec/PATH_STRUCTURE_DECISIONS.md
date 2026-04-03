# Path Structure Decision Tree

**Purpose:** Quick reference for deciding where to put files in your project structure.

**Principle:** Use canonical paths unless you have a documented reason to deviate.

---

## Decision Tree: Where Should My Code Go?

### Are you building an R package?

**YES** → R package code goes in `R/`, tests in `tests/testthat/`

**NO** → Continue to next question

---

### Do you have analysis scripts (not a package)?

**YES** → Use `analysis/` (not `scripts/` or `R/`)

**Rationale:**
- `analysis/` is specific to statistical analysis
- Distinguishes from generic `scripts/` (build, data processing, etc.)
- Distinguishes from package code (`R/`)

**Structure:**
```
analysis/
├── 01-data-prep.R
├── 02-descriptives.R
├── 03-main-analysis.R
└── 04-figures.R
```

**NO** → You might have a theory-only paper (LaTeX/proofs only)

---

## Decision Tree: Where Should My Simulations Go?

### Are your simulations part of a package project?

**YES** → Root `simulations/` directory

**Rationale:**
- Simulations use the package (test it externally)
- Not installed with package (separate from `inst/`)
- Not package code (separate from `R/`)

**Structure:**
```
package-name/
├── R/                    # Package code
├── tests/                # Unit tests
├── simulations/          # Simulation studies
│   ├── dgps.R
│   ├── run_simulations.R
│   └── figures/
└── inst/
    └── paper/            # Paper references simulation results
```

**NO, simulations are standalone** → Use `simulations/` if primarily simulations, or `analysis/` if mixed analysis + simulations

---

## Decision Tree: Where Should My Manuscript Go?

### Is the paper part of an R package?

**YES** → `inst/paper/`

**Rationale:**
- Paper travels with package
- Installed alongside package
- Standard R package location for supplementary materials

**Structure:**
```
package-name/
├── R/
├── tests/
└── inst/
    └── paper/
        ├── manuscript.tex
        ├── bibliography.bib
        └── figures/
```

**Exception:** If paper uses multiple packages or has different contributors/timeline, use separate repository.

---

**NO, standalone paper** → `manuscript/` (not `latex/` or `paper/`)

**Rationale:**
- More specific than generic `latex/` directory
- Clearer than ambiguous `paper/` (which could mean various things)
- Consistent across all standalone papers

**Structure:**
```
project-name/
├── manuscript/
│   ├── main.tex
│   ├── sections/
│   ├── bibliography.bib
│   └── figures/
└── analysis/             # If has analysis
```

---

## Decision Tree: Grant Proposals

### Are you writing a grant proposal?

**YES** → `proposal/` (not `grant/`)

**Rationale:**
- "Proposal" is more specific than "grant"
- Parallel to `manuscript/` for papers

**Structure:**
```
grant-name/
├── proposal/
│   ├── specific-aims.tex
│   ├── significance.tex
│   ├── innovation.tex
│   ├── approach.tex
│   └── bibliography.bib
├── preliminary/          # Analysis for preliminary data
└── budget/               # Budget justification
```

---

## Decision Tree: Multi-Package Projects

### Do you have 2+ R packages?

**YES** → Where should paper go?

#### Decision: Paper Location in Multi-Package Project

**Option 1: Package B presents the method** → `package-b/inst/paper/`

**Example:** global-scholars
- optimaltrees: Core tree-building (stable, published)
- doubletree: Inference method (new contribution)
- Paper presents inference → `doubletree/inst/paper/`

**Rationale:** Paper is primarily about doubletree's contribution.

---

**Option 2: Paper presents both equally** → Root `manuscript/` (or `paper/`)

**Example:** Hypothetical multi-package methods paper
- package-core: Core functionality
- package-methods: Methods using core
- Paper presents both → `project-name/manuscript/`

**Rationale:** Paper is about the joint contribution.

---

**Option 3: Paper independent of packages** → Separate repository

**Example:** Paper uses packages but also other packages
- Packages published separately
- Paper has different contributors
- Paper has different timeline

**Structure:**
```
package-a/              # Independent repo
package-b/              # Independent repo
paper-name/             # Separate repo
  ├── manuscript/
  └── analysis/         # Uses package-a and package-b
```

---

### Multi-Package: Where Should Session Notes Go?

**Multi-repo (recommended):** Root `session_notes/` ONLY

**Rationale:**
- Eliminates 3-tier redundancy (root + package-a + package-b)
- Cross-package work documented at root
- Package-specific work also documented at root (captures dependencies)
- Per-package session notes create duplication and confusion

**Structure:**
```
project-name/
├── session_notes/            # ALL work logged here
│   └── YYYY-MM-DD.md         # Cross-package and package-specific work
├── package-a/
│   └── (no session_notes/)   # NO per-package notes
└── package-b/
    └── (no session_notes/)   # NO per-package notes
```

**Monorepo:** Single `session_notes/` at root (same rationale)

---

## Quick Lookup Table

| Situation | Canonical Path | Deprecated |
|-----------|----------------|-----------|
| R package code | `R/` | None (standard) |
| R package tests | `tests/testthat/` | None (standard) |
| Analysis scripts (no package) | `analysis/` | `scripts/`, `R/` |
| Simulations (package project) | `simulations/` | `inst/simulations/`, `scripts/` |
| Paper in package | `inst/paper/` | `paper/`, `latex/` |
| Standalone paper | `manuscript/` | `latex/`, `paper/` |
| Grant proposal | `proposal/` | `grant/` |
| Multi-package session notes | Root `session_notes/` only | Per-package notes |

---

## Examples: Before and After

### Example 1: Applied Paper (No Package)

**Before (non-canonical):**
```
project/
├── latex/                # ❌ Generic
│   └── manuscript.tex
└── scripts/              # ❌ Generic
    ├── analysis1.R
    └── analysis2.R
```

**After (canonical):**
```
project/
├── manuscript/           # ✅ Specific
│   └── main.tex
└── analysis/             # ✅ Specific
    ├── 01-data-prep.R
    └── 02-main-analysis.R
```

---

### Example 2: R Package + Paper

**Before (non-canonical):**
```
package/
├── R/
├── tests/
├── paper/                # ❌ At root
│   └── manuscript.tex
└── scripts/              # ❌ Simulations in scripts/
    └── simulations.R
```

**After (canonical):**
```
package/
├── R/
├── tests/
├── inst/
│   └── paper/            # ✅ In inst/
│       └── manuscript.tex
└── simulations/          # ✅ Root simulations/
    └── run_simulations.R
```

---

### Example 3: Multi-Package Project

**Before (non-canonical):**
```
project/
├── session_notes/        # ⚠️ Root level
├── package-a/
│   ├── R/
│   └── session_notes/    # ❌ Redundant
└── package-b/
    ├── R/
    └── session_notes/    # ❌ Redundant
```

**After (canonical):**
```
project/
├── session_notes/        # ✅ Root only
├── package-a/
│   └── R/                # ✅ No per-package notes
└── package-b/
    └── R/                # ✅ No per-package notes
```

---

## Validation

**Check your project structure:**
```bash
cd your-project
/path/to/agent-assisted-research-meta/scripts/validate-structure.sh
```

**Expected output:**
- ✅ Green checks for canonical paths
- ⚠️ Yellow warnings for non-canonical but workable
- ❌ Red errors for problematic paths

---

## Migration

**Migrate non-canonical paths:**
```bash
/path/to/agent-assisted-research-meta/scripts/migrate-canonical-paths.sh /path/to/your-project
```

**What it does:**
1. Detects current structure
2. Proposes migrations
3. Creates backup
4. Executes with your approval
5. Updates file references

**Common migrations:**
- `latex/` → `manuscript/`
- `scripts/` → `analysis/`
- `paper/` → `inst/paper/` or `manuscript/`
- Remove duplicate session notes

---

## When to Deviate

**Valid reasons:**
- Legacy project (pre-2026-04-01, not worth migrating)
- Journal template requires specific structure
- External collaboration with fixed structure
- Multi-language project following language conventions
- CRAN package requirements (always follow R standards)

**Document deviations** in CLAUDE.md with rationale.

---

## See Also

- `.claude/rules/canonical-paths.md` - Full canonical path specification
- `meta-spec/EXAMPLE_PROJECTS.md` - Examples using canonical paths
- `scripts/validate-structure.sh` - Validation tool
- `scripts/migrate-canonical-paths.sh` - Migration tool
