---
paths:
  - "**/*.R"
  - "**/*.py"
  - "**/*.tex"
  - "**/*.qmd"
  - "manuscript/**"
  - "analysis/**"
  - "R/**"
  - "scripts/**"
---

# Quality Rubrics

**Purpose:** Concrete criteria for 80/90/95 thresholds by work type

---

## Philosophy

See `.claude/rules/quality-philosophy.md` for principles.

**Key insight:** Thresholds mean different things for different work types.

- **80/100 (Commit):** Good enough to save, won't make things worse
- **90/100 (PR/Share):** Ready for others to use/build on
- **95/100 (Excellence):** Would show this as reference work

These rubrics operationalize those thresholds.

---

## R Code

### 80/100 (Commit Threshold)

**Minimum requirements to commit:**

- [ ] **Runs without errors** on intended inputs
- [ ] **Basic error handling** - stop() with message for invalid inputs
- [ ] **Function documented** - roxygen2 with @param, @return, @description
- [ ] **Follows tidyverse conventions** - pipes, snake_case naming, returns tibbles

**NOT required at 80:**
- Edge case handling
- Tests beyond basic smoke tests
- Defensive checks for misuse
- Performance optimization
- Comprehensive examples

**Example 80/100:**
```r
#' Calculate summary statistics
#'
#' @param data A data frame
#' @param var Variable to summarize
#' @return A tibble with mean, sd, n
calculate_summary <- function(data, var) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame")
  }

  data |>
    summarise(
      mean = mean({{ var }}, na.rm = TRUE),
      sd = sd({{ var }}, na.rm = TRUE),
      n = n()
    )
}
```

### 90/100 (PR/Share Threshold)

**All of 80, plus:**

- [ ] **Handles edge cases** - NULL, length-0 vectors, wrong types, missing data
- [ ] **Informative error messages** - not just "Error", but actionable messages
- [ ] **Tests for main paths** - happy path + 2-3 edge cases
- [ ] **Works with tibbles and data.frames** - not just one or the other
- [ ] **Uses rlang for tidy evaluation** - if accepting expressions ({{ }}, .data, .env)
- [ ] **No warnings** from R CMD check

**Example 90/100:**
```r
#' Calculate summary statistics
#'
#' @param data A data frame or tibble
#' @param var Variable to summarize (unquoted)
#' @return A tibble with mean, sd, n
#' @examples
#' calculate_summary(mtcars, mpg)
#' calculate_summary(tibble::tibble(x = 1:10), x)
calculate_summary <- function(data, var) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame, not {.type {data}}."
    )
  }

  if (nrow(data) == 0) {
    cli::cli_abort("{.arg data} must have at least one row.")
  }

  data |>
    summarise(
      mean = mean({{ var }}, na.rm = TRUE),
      sd = sd({{ var }}, na.rm = TRUE),
      n = n()
    )
}

# Tests:
test_that("calculate_summary works", {
  result <- calculate_summary(mtcars, mpg)
  expect_equal(nrow(result), 1)
  expect_true(all(c("mean", "sd", "n") %in% names(result)))
})

test_that("calculate_summary handles edge cases", {
  expect_error(
    calculate_summary("not a df", x),
    "data frame"
  )
  expect_error(
    calculate_summary(mtcars[0, ], mpg),
    "at least one row"
  )
})
```

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Comprehensive tests** - including failure modes, boundary conditions
- [ ] **Defensive against misuse** - validates assumptions, helpful errors
- [ ] **Performance considered** - vectorized, avoids unnecessary loops/copies
- [ ] **Examples in documentation** - realistic use cases
- [ ] **Would show this as reference code** - exemplifies best practices
- [ ] **Graceful degradation** - works with edge cases, doesn't just error

**Example 95/100:**
```r
#' Calculate summary statistics with flexible grouping
#'
#' @param data A data frame or tibble
#' @param var Variable to summarize (unquoted)
#' @param ... Optional grouping variables
#' @return A tibble with mean, sd, n (and grouping vars if provided)
#' @examples
#' # Basic usage
#' calculate_summary(mtcars, mpg)
#'
#' # With grouping
#' calculate_summary(mtcars, mpg, cyl)
#' calculate_summary(mtcars, mpg, cyl, am)
#'
#' # Works with tibbles
#' tibble::tibble(x = 1:100, g = rep(1:10, 10)) |>
#'   calculate_summary(x, g)
calculate_summary <- function(data, var, ...) {
  # Input validation
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame, not {.type {data}}."
    )
  }

  if (nrow(data) == 0) {
    cli::cli_warn(
      "{.arg data} has zero rows. Returning empty result."
    )
    return(tibble::tibble(mean = numeric(), sd = numeric(), n = integer()))
  }

  # Compute summary
  result <- data |>
    group_by(...) |>
    summarise(
      mean = mean({{ var }}, na.rm = TRUE),
      sd = sd({{ var }}, na.rm = TRUE),
      n = n(),
      .groups = "drop"
    )

  # Warn about all-NA groups
  if (any(is.nan(result$mean))) {
    cli::cli_warn(
      "Some groups have no non-NA values."
    )
  }

  result
}

# Comprehensive tests with edge cases and boundaries
```

---

## Python Code

### 80/100 (Commit Threshold)

- [ ] **Runs without errors** on intended inputs
- [ ] **Basic error handling** - raise with message for invalid inputs
- [ ] **Function documented** - docstring with Args, Returns
- [ ] **Type hints** on function signature
- [ ] **Follows PEP 8** - naming, spacing

**NOT required:** edge cases, comprehensive tests, defensive checks

### 90/100 (PR/Share Threshold)

**All of 80, plus:**

- [ ] **Handles edge cases** - None, empty sequences, wrong types
- [ ] **Informative error messages** - specific about what's wrong
- [ ] **Tests for main paths** - happy path + edge cases
- [ ] **Type hints** on complex types (List, Dict, Optional)
- [ ] **No linter warnings** (pylint/flake8)

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Comprehensive tests** - including error conditions, boundaries
- [ ] **Defensive programming** - validates assumptions
- [ ] **Performance considered** - uses appropriate data structures
- [ ] **Examples in docstring**
- [ ] **Would show as reference code**

---

## LaTeX Papers

### 80/100 (Commit Threshold)

- [ ] **Compiles without errors**
- [ ] **Math notation is correct** - no typos in equations
- [ ] **References compile** - bibliography works
- [ ] **Figures render** - included and visible
- [ ] **No [TODO] or [XXX] in body text**

**NOT required:** polished prose, comprehensive references, perfect formatting

**Acceptable at 80:**
- Some awkward phrasing (mark with % TODO for later)
- Missing some references (mark with \cite{CITE_NEEDED})
- Minor formatting inconsistencies

### 90/100 (PR/Share Threshold)

**All of 80, plus:**

- [ ] **No TODO comments** in body text (only in % comments if needed)
- [ ] **Clear prose** - no awkward or confusing sentences
- [ ] **Comprehensive references** - all claims cited
- [ ] **Consistent formatting** - follows journal style
- [ ] **Tables/figures have captions** - descriptive and complete
- [ ] **Math is well-explained** - introduced before used
- [ ] **Compiles without warnings**

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Polished prose** - could submit to journal as-is
- [ ] **Perfect formatting** - matches journal template exactly
- [ ] **All cross-references work** - equations, figures, tables, sections
- [ ] **Accessible** - acronyms defined, notation explained
- [ ] **Proofread** - no typos, grammar correct
- [ ] **Would show as exemplar**

---

## Quarto Documents (.qmd)

### 80/100 (Commit Threshold)

- [ ] **Renders without errors**
- [ ] **Code chunks run** - no execution errors
- [ ] **Basic formatting** - headings, paragraphs
- [ ] **Figures show** - plots visible in output

**NOT required:** polished prose, comprehensive formatting, perfect YAML

### 90/100 (PR/Share Threshold)

**All of 80, plus:**

- [ ] **Clean output** - no warnings or messages unless intentional
- [ ] **Good formatting** - uses Quarto features (callouts, cross-refs)
- [ ] **Code is readable** - chunk options appropriate (echo/message/warning)
- [ ] **Figures have captions**
- [ ] **Renders to intended format** - HTML/PDF/docx as required

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Publication-ready** - could share publicly
- [ ] **Effective visualization** - figures are clear and well-designed
- [ ] **Reproducible** - sessionInfo(), package versions noted
- [ ] **Accessible** - alt text on figures
- [ ] **Well-structured** - clear sections, logical flow

---

## Data Analysis Scripts

### 80/100 (Commit Threshold)

- [ ] **Runs without errors**
- [ ] **Produces expected outputs** - files, plots, tables
- [ ] **Basic comments** - explains what, not just code
- [ ] **Saves results** - doesn't just print to console

**NOT required:** comprehensive error handling, optimized, fully documented

**Acceptable at 80:**
- Hardcoded paths (if documented)
- Some magic numbers (if clear what they are)
- Basic plots (not polished)

### 90/100 (PR/Share Threshold)

**All of 80, plus:**

- [ ] **Handles missing data** - explicit strategy
- [ ] **Good comments** - explains why, not just what
- [ ] **Parameterized** - no hardcoded values (or clearly marked)
- [ ] **Produces interpretable outputs** - labeled, units clear
- [ ] **Checkpoint saves** - intermediate results saved
- [ ] **Runs from clean state** - doesn't depend on workspace

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Fully reproducible** - includes package versions, seed setting
- [ ] **Robust** - handles different data shapes/sizes
- [ ] **Well-organized** - clear sections, logical flow
- [ ] **Validated** - includes sanity checks, diagnostic plots
- [ ] **Publication-ready outputs** - polished figures, formatted tables
- [ ] **Would share as exemplar**

---

## Quick Reference Table

| Work Type | 80/100 | 90/100 | 95/100 |
|-----------|--------|--------|--------|
| **R Code** | Runs + basic docs | + edge cases + tests | + defensive + optimized |
| **Python Code** | Runs + type hints + docs | + edge cases + tests | + comprehensive tests + examples |
| **LaTeX Papers** | Compiles + accurate | + no TODOs + clear prose | + polished + publication-ready |
| **Quarto Docs** | Renders + runs | + clean output + formatting | + reproducible + accessible |
| **Analysis Scripts** | Runs + outputs | + handles data issues + documented | + reproducible + robust + validated |

---

## Using These Rubrics

### Before Committing

Ask: "Is this at least 80/100?"

- Check rubric for work type
- Verify all 80/100 items
- If not, keep working
- Don't commit at 70/100 to "save time"

### Before PR/Sharing

Ask: "Is this at least 90/100?"

- Check rubric for work type
- Verify all 90/100 items (includes all 80/100)
- Get to 90 before asking others to review
- Don't create PR at 85/100

### When Aiming for Excellence

Ask: "Is this 95/100?"

- Check rubric for work type
- Verify all 95/100 items (includes all 80 and 90)
- This is optional, not required
- But if aiming for it, go all the way

---

## Borderline Cases

### "I think this is 80, but unsure"

**Check specifics:**
- Does it meet every 80/100 item in rubric? (not most, all)
- If missing one item, it's <80
- If meets all items, it's ≥80

**Don't round up:** 75 is not "close enough to 80"

### "This exceeds 80 in some ways, misses in others"

**Weakest link matters:**
- If fails one 80/100 criterion, overall score is <80
- Can't compensate by exceeding elsewhere
- Example: Great docs but doesn't handle errors → <80

### "Different parts are different quality"

**Score by weakest component:**
- If file A is 90/100 and file B is 70/100, overall is <80
- Raise file B before committing
- Or separate commits (if independent)

---

## Calibration Examples

### R Code: Borderline 80

**Code:**
```r
process_data <- function(x) {
  # Missing: error handling, documentation
  x |>
    filter(!is.na(value)) |>
    mutate(log_value = log(value))
}
```

**Score: <80** (no error handling, no docs)

**To reach 80:**
```r
#' Process data by filtering NAs and computing log values
#'
#' @param x A data frame with a `value` column
#' @return A data frame with additional `log_value` column
process_data <- function(x) {
  if (!is.data.frame(x)) {
    stop("`x` must be a data frame")
  }
  if (!"value" %in% names(x)) {
    stop("`x` must have a `value` column")
  }

  x |>
    filter(!is.na(value)) |>
    mutate(log_value = log(value))
}
```

### LaTeX: Borderline 90

**Text:**
```latex
The results are shown in Figure 1. We see that the effect is significant
[TODO: add interpretation]. This is consistent with prior work [CITE].
```

**Score: <90** (has TODO, has [CITE])

**To reach 90:**
```latex
The results are shown in Figure~\ref{fig:results}. The treatment effect
is 2.3 units (95\% CI: 1.1--3.5), indicating a substantial and statistically
significant improvement. This finding is consistent with prior randomized
trials in similar populations \citep{smith2023, jones2024}.
```

---

## See Also

- `.claude/rules/quality-philosophy.md` - Principles behind thresholds
- `.claude/rules/quality-gates.md` - Scoring system
- `CLAUDE.md` - Core principles section (80/90/95 table)
- `meta-spec/RESEARCH_CONSTITUTION.md` - §9 Quality invariants

---

## Version History

- **2026-04-02**: Initial version - concrete rubrics for R, Python, LaTeX, Quarto, analysis
