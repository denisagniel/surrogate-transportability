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

<!-- GENERATED from .claude/rules/quality-rubrics.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Quality Rubrics

> **Quality docs map:** `quality-philosophy.md` = *why* (the principle). This file = *what* good looks like per work type (concrete checklists). `quality-gates.md` = *scoring* (deductions, enforcement).

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

## Grant Proposals

**Note:** Grant thresholds are HIGHER than code. 80/100 = commit (good enough to save), but 90/100 = submission-ready (not 80).

### 80/100 (Commit Threshold - Per Section)

**Minimum requirements to commit a section:**

- [ ] **Follows outline** - Content matches outline structure and boundaries
- [ ] **Covers required points** - All outline points addressed
- [ ] **No major gaps** - No obvious missing content
- [ ] **Compiles/renders** - LaTeX compiles or document renders
- [ ] **Basic flow** - Paragraphs connect logically within section

**NOT required at 80:**
- Cross-section coherence (checked later with `/coherence-check`)
- Citation completeness (added during revision)
- Style match (improved during editing)
- External review quality

**Acceptable at 80:**
- Some repetition across sections (will catch with coherence check)
- Placeholder citations ([CITE])
- Generic phrasing (will match voice during editing)
- Rough transitions

**Example 80/100 (Significance section):**
```
✅ Establishes health burden with statistics [even if needs citation]
✅ Identifies knowledge gap [even if not eloquently stated]
✅ Presents preliminary data [even if formatting rough]
✅ States impact [even if generic phrasing]
❌ May repeat burden statement from Aims (acceptable, will catch later)
❌ May lack some citations (acceptable, will add during revision)
```

---

### 85/100 (Internal Review Ready)

**All of 80, plus:**

- [ ] **No significant redundancy** - Coherence check passed, major repetition eliminated
- [ ] **Terminology consistent** - Key terms used consistently across sections
- [ ] **Cross-references valid** - References to other sections are accurate
- [ ] **Content in right sections** - No major boundary violations (methods in Approach, not Significance)

**NOT required at 85:**
- Perfect voice match
- All citations validated
- External-review-ready polish

**Example 85/100 (after coherence check):**
```
✅ Burden statement in Significance, referenced (not repeated) in Innovation
✅ Uses "acute decompensation" consistently (not switching to "worsening")
✅ Cross-reference "Significance, Fig. 2" actually points to existing figure
✅ Preliminary data in Significance section, referenced in Approach
❌ May still have generic phrasing (acceptable, will fix during editing)
❌ May have citation gaps (acceptable, will add before external review)
```

---

### 90/100 (Submission Ready)

**All of 85, plus:**

- [ ] **Matches user's voice** - Style review passed, sounds like user wrote it
- [ ] **Citations complete and accurate** - All claims cited, citations validated
- [ ] **No TODO markers** - All placeholders resolved
- [ ] **Meets quality standards** - Clear, professional, ready for reviewers
- [ ] **Page limits met** - Within funder requirements

**This is submission threshold for grants** (higher than code's 80/100)

**NOT required at 90:**
- Perfection
- Zero typos (acceptable if rare and minor)
- Guaranteed funding (no one can guarantee that)

**Example 90/100 (submission-ready):**
```
✅ Sounds like user's natural voice (not generic AI)
✅ All burden/gap statements cited with authoritative sources
✅ No [CITE] or [TODO] markers
✅ Professional quality throughout
✅ Specific Aims: 1 page, Approach: 12 pages (within NIH limits)
❌ Might have minor typo on page 8 (acceptable if caught in final proofread)
```

---

### 95/100 (Excellence)

**All of 90, plus:**

- [ ] **Exemplary clarity** - Every paragraph is crisp and clear
- [ ] **Compelling narrative** - Reviewers will be engaged, not just informed
- [ ] **Strategic alignment** - Perfectly matches funder priorities
- [ ] **Zero errors** - Proofread, polished, perfect
- [ ] **Would show as exemplar** - This is how grants should be written

**This is aspirational, not required**

**Example 95/100 (exemplary):**
```
✅ Opening paragraph immediately engages reviewer
✅ Every sentence serves clear purpose
✅ Innovation section compellingly argues novelty
✅ Approach is detailed but readable
✅ Zero typos, zero formatting inconsistencies
✅ Would share with colleagues as model proposal
```

---

### Grant Quality by Section

**Different sections, different standards:**

#### Specific Aims (1 page)

**80/100:**
- Three aims stated
- Problem and gap mentioned
- Innovation and impact mentioned
- Compiles, fits on 1 page

**90/100:** All of 80, plus:
- Aims sharply stated (active verbs, clear outcomes)
- Logical flow between aims
- Impact compelling
- Matches user's confident aims-page voice
- Within 1 page (not 1.1 pages)

**95/100:** All of 90, plus:
- Opening immediately hooks reviewer
- Every word counts (no wasted space)
- Aims build perfectly on each other
- Closing is inspiring

#### Significance (2-3 pages)

**80/100:**
- Burden established
- Gap identified
- Preliminary data presented
- Impact stated

**90/100:** All of 80, plus:
- Burden cited with authoritative sources
- Gap argued convincingly with evidence
- Preliminary data appropriately detailed (not too much, not too little)
- Impact specific and measurable
- No repetition with Aims or Innovation

**95/100:** All of 90, plus:
- Reviewers will remember the gap (compellingly stated)
- Preliminary data creates confidence in team
- Impact is transformative, not incremental

#### Innovation (1-2 pages)

**80/100:**
- States what's innovative
- Mentions advantages over existing
- References gap from Significance

**90/100:** All of 80, plus:
- Innovation is specific and credible (not overstated)
- Advantages clearly argued
- Doesn't repeat Significance (references and builds on it)
- Paradigm shift potential is clear

**95/100:** All of 90, plus:
- Reviewers will be excited about novelty
- Addresses "why hasn't this been done before" preemptively
- Innovation is transformative but achievable

#### Approach (12 pages for R01)

**80/100:**
- Methods described for each aim
- Rationale provided
- Expected outcomes stated
- Potential problems mentioned

**90/100:** All of 80, plus:
- Methods detailed enough to evaluate feasibility
- Sample sizes justified with power calculations
- Potential problems have credible solutions
- Timeline is realistic
- No methods details in Significance/Innovation (proper boundaries)
- References preliminary data appropriately (not re-presenting)

**95/100:** All of 90, plus:
- Methods inspire confidence (detailed but readable)
- Reviewers can't identify feasibility concerns
- Potential problems section shows sophisticated thinking
- Timeline has appropriate go/no-go decision points

---

### Grant Quality Checklist (All Sections Complete)

**Before submission, verify:**

#### Content (90/100 required)
- [ ] All outline points covered
- [ ] No significant redundancy (coherence check passed)
- [ ] Terminology consistent across sections
- [ ] All cross-references valid
- [ ] Content in correct sections (boundary check passed)
- [ ] All claims cited with authoritative sources
- [ ] Citations validated (accurate)
- [ ] No TODO or [CITE] markers

#### Voice and Style (90/100 required)
- [ ] Matches user's style guide (if exists)
- [ ] Sentence length appropriate
- [ ] Active/passive voice balance appropriate
- [ ] Professional but accessible tone
- [ ] Section-specific styles used (aims more confident than significance)

#### Format (90/100 required)
- [ ] Compiles/renders without errors or warnings
- [ ] Page limits met (Aims: 1 page, Approach: typically 12 pages for R01)
- [ ] Formatting consistent (citations, headings, lists)
- [ ] Figures and tables properly captioned
- [ ] Bibliography complete and formatted correctly

#### Funder Requirements (90/100 required)
- [ ] Addresses all review criteria explicitly
- [ ] Aligns with funder priorities
- [ ] Includes required sections (varies by funder)
- [ ] Budget consistent with scope
- [ ] Timeline realistic

**If any item fails, not at 90/100 (not submission-ready)**

---

### Common Grant Quality Issues

#### Issue: Repetition not caught

**Symptom:** Same burden/gap/innovation statements in multiple sections

**Quality impact:** Reduces score from 85 to <80

**Fix:** Run `/coherence-check` after drafting 2-3 sections

**Prevention:** Use `/grant-outline` to assign content to specific sections

---

#### Issue: Style doesn't match user

**Symptom:** Generic AI prose, sentences too long/short, wrong voice

**Quality impact:** Reduces score from 90 to 80-85

**Fix:** Run `style-reviewer` and edit with `/edit-with-context`

**Prevention:** Create style guide with `/grant-style-guide` before drafting

---

#### Issue: Missing citations

**Symptom:** Factual claims without sources, [CITE] markers

**Quality impact:** Reduces score from 90 to 80-85

**Fix:** Run `/citation-manager` gap-check and add missing citations

**Prevention:** Add citations during drafting, not just at end

---

#### Issue: Cross-reference broken

**Symptom:** "See Significance, Fig. 2" but figure doesn't exist

**Quality impact:** Reduces score from 85 to <80

**Fix:** Run `/coherence-check` which validates cross-references

**Prevention:** Create figures as you write, reference immediately

---

### Grant vs. Code Quality Thresholds

**Key difference: Grants need 90/100 for submission, code only needs 80/100**

| Work Type | Commit (Save) | Share/Submit | Excellence |
|-----------|---------------|--------------|------------|
| Code | 80 | 80-85 | 90-95 |
| Grants | 80 (per section) | 90 (full proposal) | 95 |

**Why grants are higher:**
- High stakes (funding, career impact)
- One-shot opportunity (can't patch after submission)
- Competitive (reviewers compare proposals)
- Reputation matters (your name on it)
- External reviewers (not just internal team)

**Implication:** Don't submit grant at 80-85, keep working to 90+

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
| **Grant Proposals** | Follows outline + covers points | + coherent + cited + voice match | + compelling + zero errors |
| **R Code** | Runs + basic docs | + edge cases + tests | + defensive + optimized |
| **Python Code** | Runs + type hints + docs | + edge cases + tests | + comprehensive tests + examples |
| **LaTeX Papers** | Compiles + accurate | + no TODOs + clear prose | + polished + publication-ready |
| **Quarto Docs** | Renders + runs | + clean output + formatting | + reproducible + accessible |
| **Analysis Scripts** | Runs + outputs | + handles data issues + documented | + reproducible + robust + validated |

**Note:** Grants require 90/100 for submission (higher than code's 80/100 threshold)

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
- `meta-spec/RESEARCH_CONSTITUTION.md` - the twelve numbered workflow invariants
- Domain invariants by lane: `.claude/rules/r-code-conventions.md` §2–§3 (software), `.claude/rules/proof-protocol.md` (proofs), `.claude/rules/paper-protocol.md` (writing), `.claude/skills/simulations/SKILL.md` (simulations)

---

## Version History

- **2026-04-22**: Add grant proposals rubrics (Phase 5 of grant infrastructure) - 80/85/90/95 thresholds with section-specific criteria
- **2026-04-02**: Initial version - concrete rubrics for R, Python, LaTeX, Quarto, analysis
