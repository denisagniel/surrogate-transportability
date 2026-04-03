---
paths:
  - "**/*.R"
  - "**/*.py"
  - "**/*.js"
  - "**/*.ts"
  - "R/**"
  - "src/**"
  - "scripts/**"
---

# Decision Frameworks

**Purpose:** Consistent judgment on recurring technical decisions

---

## Core Principle

**Common decisions should have systematic answers, not arbitrary choices.**

Why this matters:
- Reduces cognitive load (don't re-decide same question)
- Improves consistency (same question → same answer)
- Speeds up work (no decision paralysis)
- Builds patterns (users learn what to expect)

---

## 1. Code Organization

**Question:** Where does this new code go?

### Decision Tree

```
Is this code new functionality?
    ↓
   YES
    ↓
  Is it exported (user-facing)?
    ↓
   YES → Create new file: R/{feature-name}.R
    │     Export from package/module
    │
   NO → Is it a helper for specific feature?
    │
   YES → Add to existing file: R/{feature-name}-helpers.R
    │
   NO → General utility?
        → Add to R/utils.R or create utils/{category}.R

    ↓
   NO (modifying existing)
    ↓
  Is behavior change intentional?
    ↓
   YES → Edit existing function
    │     Update tests
    │     Note in NEWS
    │
   NO (bug fix) → Minimal change to existing function
                  Add regression test
                  Note in NEWS
```

### Quick Table

| Situation | Action | Example |
|-----------|--------|---------|
| New exported function | New file R/{name}.R | R/calculate-stats.R |
| Helper for exported function | Add to R/{name}-helpers.R | R/calculate-stats-helpers.R |
| General utility | Add to R/utils.R | R/utils.R |
| Modify behavior | Edit existing, update tests | Edit function, update test-{name}.R |
| Fix bug | Minimal edit, regression test | Change 1 line, add test case |
| Refactor | Only if <80 quality or blocking | Improve structure, keep API |

### Anti-Patterns

❌ **Don't do:**
- Create new file for every small helper
- Put unrelated code in same file
- Refactor for no reason (if quality is ≥80)
- Change file structure mid-project without reason

✅ **Do:**
- Group related code together
- Keep files focused (one main feature per file)
- Refactor only when quality <80 or functionality blocked
- Use subdirectories for large projects (R/models/, R/data/, etc.)

---

## 2. Testing Strategy

**Question:** How much testing for this change?

### Decision Table

| Change Type | Tests Required | Rationale |
|-------------|----------------|-----------|
| **Bug fix** | Regression test for that bug | Prevent recurrence |
| **New function (simple)** | Happy path + 2-3 edge cases | Verify basic correctness |
| **New function (complex)** | Comprehensive suite | High complexity → high testing |
| **Core algorithm** | Exhaustive tests | Critical code needs confidence |
| **Exported API** | Examples + tests | Users depend on this |
| **Internal helper** | Basic smoke tests | Lower risk |
| **Exploratory code** | Minimal (optional) | Temporary code |
| **Refactor** | Maintain existing tests | Behavior shouldn't change |

### Specific Guidance

#### Bug Fix
```
Minimum: One test that would have caught the bug

test_that("bug #123: handles empty input", {
  # This failed before fix
  expect_no_error(process_data(data.frame()))
})
```

#### New Function (Simple)
```
Minimum: 3-5 tests

1. Happy path (normal input)
2. Edge case: empty/NULL
3. Edge case: wrong type
4. (Optional) Edge case: boundary value
```

#### New Function (Complex)
```
Minimum: 10+ tests

- Multiple happy paths (different input types)
- All edge cases (NULL, empty, wrong type, boundary)
- Error conditions (invalid input, violated assumptions)
- Integration with other functions
```

#### Core Algorithm (Estimator, Model, Statistical Method)
```
Minimum: 20+ tests

- Known results (compare to reference implementation)
- Boundary conditions (n=1, n=large, edge of parameter space)
- Robustness (outliers, missing data, extreme values)
- Properties (invariances, symmetries)
- Stress test (large data, difficult cases)
```

---

## 3. Documentation Level

**Question:** How much documentation?

### Decision Table

| Code Type | Documentation | Example |
|-----------|--------------|---------|
| **Internal function** | roxygen2: @param, @return | Minimal but present |
| **Exported function** | Above + @description, @details | User-facing needs clarity |
| **Complex algorithm** | Above + @references, long @details | Explain approach |
| **Package** | Above + README, vignette, pkgdown site | Full user documentation |

### Specific Guidance

#### Internal Function (Not Exported)
```r
#' Calculate log-likelihood
#'
#' @param data Data frame
#' @param params Parameter vector
#' @return Log-likelihood value
calculate_loglik <- function(data, params) {
  # Implementation
}
```

**Minimum:**
- One-line description
- @param for each parameter
- @return for output

**NOT required:**
- @examples
- Long @details
- @references

#### Exported Function
```r
#' Calculate summary statistics
#'
#' Computes mean, standard deviation, and sample size for a variable,
#' with optional grouping.
#'
#' @param data A data frame or tibble
#' @param var Variable to summarize (unquoted)
#' @param ... Optional grouping variables
#' @return A tibble with columns: mean, sd, n (and grouping vars if provided)
#' @examples
#' calculate_summary(mtcars, mpg)
#' calculate_summary(mtcars, mpg, cyl)
#' @export
calculate_summary <- function(data, var, ...) {
  # Implementation
}
```

**Minimum:**
- Clear @description (what it does)
- @details if behavior is non-obvious
- @param with type information
- @return with structure description
- @examples with realistic use cases
- @export tag

#### Complex Algorithm
```r
#' Compute doubly robust estimator
#'
#' Implements the augmented inverse propensity weighted estimator
#' for average treatment effects, combining outcome regression and
#' propensity score models.
#'
#' The estimator is consistent if either the outcome model or the
#' propensity score model is correctly specified (double robustness).
#'
#' @param data Data frame with columns for outcome, treatment, covariates
#' @param outcome Name of outcome variable
#' @param treatment Name of treatment variable (0/1)
#' @param covariates Character vector of covariate names
#' @param outcome_model Model formula for outcome (default: linear)
#' @param ps_model Model formula for propensity score (default: logistic)
#' @return A list with components:
#'   \item{estimate}{Point estimate of ATE}
#'   \item{std_error}{Standard error}
#'   \item{conf_interval}{95% confidence interval}
#' @references
#' Robins, J. M., Rotnitzky, A., & Zhao, L. P. (1994). Estimation of
#' regression coefficients when some regressors are not always observed.
#' \emph{Journal of the American Statistical Association}, 89, 846-866.
#' @examples
#' # Simulated data
#' data <- generate_trial_data(n = 500)
#' dr_estimate(data, "Y", "A", c("X1", "X2"))
#' @export
dr_estimate <- function(data, outcome, treatment, covariates,
                        outcome_model = NULL, ps_model = NULL) {
  # Implementation
}
```

**Minimum:**
- Detailed @description (what + context)
- @details explaining approach/theory
- @param with defaults noted
- @return with full structure
- @examples with realistic scenarios
- @references for theoretical basis

---

## 4. Skill vs Direct Action

**Question:** Should I use a skill or handle directly?

### Decision Tree

```
Does a skill exist for this EXACT task?
    ↓
   YES → Use the skill
    │
   NO → Is there a skill for a RELATED task?
        ↓
       YES → Would invoking skill + adapting be faster than direct?
        │    ↓
        │   YES → Use skill
        │    ↓
        │   NO → Handle directly (skill overhead not worth it)
        │
       NO → Is the task complex enough to benefit from skill structure?
            ↓
           YES → Is there a skill for this? (Search .claude/skills/)
            │    ↓
            │   YES → Use it
            │    ↓
            │   NO → Handle directly (don't create skill unless recurring)
            │
           NO → Handle directly (simple tasks don't need skills)
```

### Quick Guide

| Situation | Action | Rationale |
|-----------|--------|-----------|
| Skill exists for exact task | Use skill | That's what it's for |
| Skill exists for related task, simple adapt | Use skill | Leverage structure |
| Skill exists but heavy adaptation needed | Handle directly | Overhead not worth it |
| No skill, task is complex | Do directly | Don't create skills mid-task |
| No skill, task is simple | Do directly | Skills have overhead |
| No skill, task might recur | Consider creating skill (after task done) | But finish current task first |

### Examples

**Use skill:**
```
Task: Review R package code
→ /review-r exists for this exact task
→ Use /review-r
```

**Handle directly:**
```
Task: Fix typo in one function
→ No skill for "fix typo"
→ Simple task, handle directly
→ Read file, fix typo, verify
```

**Use skill (related task):**
```
Task: Write R function with tidyverse style
→ /writing-tidyverse-r covers this
→ Use skill for guidance
```

**Handle directly (too specific):**
```
Task: Refactor specific function in this package
→ No skill for this specific refactoring
→ Do directly (too specific for skill)
```

---

## 5. Tool Selection

**Question:** Which tool should I use?

### Primary Rule

**Use dedicated tools, not Bash, for file operations.**

| Need | Correct Tool | NOT |
|------|-------------|-----|
| **Read file** | Read | Bash: cat, head, tail, sed |
| **Search files** | Glob | Bash: find, ls |
| **Search content** | Grep | Bash: grep, rg, ag |
| **Edit file** | Edit | Bash: sed, awk, perl |
| **Write new file** | Write | Bash: cat >, echo > |
| **Run command** | Bash | (This is correct use of Bash) |

### Why Dedicated Tools?

**Better user experience:**
- User sees what you're doing (tool names are clear)
- User can review changes before accepting (Edit shows diffs)
- Error messages are clearer

**Better for you:**
- Tools handle edge cases (special characters, encoding)
- Tools prevent common mistakes (Edit requires Read first)

### Bash is for...

**System commands and terminal operations:**
- Compiling code (R CMD check, make, cargo build)
- Running tests (Rscript, pytest, npm test)
- Git operations (git log, git diff, git commit)
- Process management (ps, kill, pkill)
- System info (df, free, uname)
- Package management (R installation, pip install)

**NOT for file manipulation:**
- Don't use cat to read files → use Read
- Don't use sed to edit files → use Edit
- Don't use find to search → use Glob
- Don't use grep to search content → use Grep

### Decision Table

| Task | Tool | Example |
|------|------|---------|
| Read first 50 lines | Read with limit | Read, limit=50 |
| Find all R files | Glob | Glob "**/*.R" |
| Search for pattern | Grep | Grep "function_name" "**/*.R" |
| Edit function in file | Edit (after Read) | Read → Edit |
| Create new file | Write | Write with content |
| Compile R package | Bash | Bash: R CMD check |
| Run tests | Bash | Bash: Rscript -e "devtools::test()" |
| Check git status | Bash | Bash: git status |

---

## Quick Reference

### Code Organization

| Situation | Action |
|-----------|--------|
| New exported function | New file R/{name}.R |
| Helper function | Add to R/{name}-helpers.R |
| Bug fix | Minimal edit + regression test |
| Refactor | Only if quality <80 or blocking |

### Testing

| Change | Tests |
|--------|-------|
| Bug fix | Regression test |
| New simple function | Happy path + 2-3 edge cases |
| New complex function | Comprehensive suite (10+ tests) |
| Core algorithm | Exhaustive tests (20+ tests) |

### Documentation

| Code Type | Docs |
|-----------|------|
| Internal function | @param, @return |
| Exported function | + @description, @examples |
| Complex algorithm | + @details, @references, long examples |

### Skills

| Situation | Action |
|-----------|--------|
| Skill exists for task | Use skill |
| No skill, task simple | Handle directly |
| No skill, task complex | Still handle directly (don't create mid-task) |

### Tools

| Need | Tool |
|------|------|
| File operations | Read, Edit, Write, Glob, Grep |
| System operations | Bash |

---

## Integration

### With Quality Rubrics

Documentation and testing levels align with quality thresholds:
- 80/100: Basic docs + basic tests (per frameworks above)
- 90/100: Good docs + edge case tests
- 95/100: Comprehensive docs + exhaustive tests

See: `.claude/rules/quality-rubrics.md`

### With R Code Conventions

Code organization follows R package conventions:
- Exported functions in R/
- Helpers in R/*-helpers.R
- Tests in tests/testthat/

See: `.claude/rules/r-code-conventions.md`

### With Package Development Skills

When developing R packages:
- Use package development skills for guidance
- Follow frameworks above for specific decisions
- Skills: developing-packages-r, testing-r-packages, cli-r

---

## See Also

- `.claude/rules/r-code-conventions.md` - R-specific conventions
- `.claude/rules/quality-rubrics.md` - Quality thresholds
- `.claude/skills/` - Available skills
- `.claude/rules/plan-first-workflow.md` - When to plan vs execute

---

## Version History

- **2026-04-02**: Initial version - systematic decision frameworks
