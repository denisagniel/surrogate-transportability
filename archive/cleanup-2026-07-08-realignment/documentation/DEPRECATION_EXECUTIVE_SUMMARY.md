# Deprecation Work: Executive Summary

**Date:** 2026-05-01
**Status:** Planning Complete - Ready for Implementation
**Authority:** `inst/presentation/slides.qmd` (22 slides, peer-reviewed)

---

## The Problem

The presentation slides, paper, and R package tell different stories about what the surrogate transportability method "is." This creates confusion for users and reviewers.

**Example Misalignments:**
- Paper treats all functionals equally; **slides emphasize correlation as THE functional**
- Paper emphasizes TV vs Wasserstein; **slides emphasize X-level vs Obs-level**
- Package has 6 functionals; **slides present only 1 (plus 2 brief examples)**
- Package has Bayesian inference; **slides present frequentist only**

---

## The Solution

Align everything to the **authoritative slides** by:
1. Flagging non-core functions as "experimental"
2. Reframing paper to match slides' emphasis
3. Updating documentation to clarify hierarchy

**No breaking changes.** Just clearer communication about what's core vs alternative.

---

## What's CORE (Keep Prominent)

✅ **Correlation functional** - THE primary measure
✅ **X-level vs Obs-level** - THE key distinction
✅ **TV and Wasserstein metrics** - Operationalized distance measures
✅ **Hit-and-run MCMC** - Sampling method
✅ **Functional delta method** - Inference approach

---

## What's EXPERIMENTAL (Flag as Non-Core)

⚠️ **Concordance, PPV, NPV, Conditional Mean** - Alternative functionals
⚠️ **CATE Covariance** - Different paradigm (within-study, not across-study)
⚠️ **Bayesian Inference** - Alternative inference (not the core method)
⚠️ **Sample Splitting** - Advanced technique

---

## Three Documents Created

### 1. DEPRECATIONS.md (The Roadmap)
**What:** Comprehensive deprecation strategy
**Who:** For implementers
**When:** Read first to understand full scope
**Length:** 600 lines

**Key Sections:**
- Categories 1-4: What to deprecate/flag/keep/internalize
- Paper alignment tasks
- Migration timeline (Priority 1-3)
- FAQ

### 2. SLIDES_VS_PAPER_VS_PACKAGE.md (The Comparison)
**What:** Component-by-component comparison tables
**Who:** For quick reference
**When:** Use to check alignment status
**Length:** 350 lines

**Key Tables:**
- Functionals comparison (9 components)
- Geometries comparison (4 components)
- Distance metrics (5 components)
- Current vs target alignment scores

### 3. IMPLEMENTATION_GUIDE.md (The Cookbook)
**What:** Step-by-step instructions with code
**Who:** For developers implementing changes
**When:** Follow sequentially Priority 1 → 2 → 3
**Length:** 650 lines

**Key Features:**
- Exact line numbers
- Code templates
- Verification commands
- Troubleshooting guide

---

## Priority 1: Critical (Do First)

**Goal:** Make experimental functions clearly marked
**Time:** 4-6 hours
**Impact:** Users know what the core method is

**Tasks:**
1. Add experimental note to `functional_concordance()`
2. Add experimental note to `functional_ppv()`
3. Add experimental note to `functional_npv()`
4. Add experimental note to `functional_conditional_mean()`
5. Add alternative paradigm note to `functional_cate_covariance()`
6. Add alternative inference note to `posterior_inference()`
7. Update README.md to emphasize core workflow
8. Update primary vignette to match slides

**Verification:** `devtools::check()` passes, help files show notes

---

## Priority 2: Important (Do Second)

**Goal:** Paper matches slides' framing
**Time:** 8-10 hours
**Impact:** Consistent story across all materials

**Tasks:**
1. Add PTE misleading example to paper (matches Slide 13)
2. Strengthen X-level vs Obs-level framing
3. Generate figure for PTE example
4. Update simulation results section

**Verification:** Paper compiles, example matches slides

---

## Priority 3: Polish (Do Third)

**Goal:** Professional documentation
**Time:** 2-3 hours
**Impact:** Complete alignment

**Tasks:**
1. Update NEWS.md with deprecation notices
2. Add lifecycle badges to functions
3. Build pkgdown site
4. Final verification

**Verification:** All checks pass, site builds cleanly

---

## Alignment Scores

| Comparison | Current | After P1 | After P2 | After P3 |
|------------|---------|----------|----------|----------|
| Slides → Paper | 63/100 | 70/100 | **90/100** | 95/100 |
| Slides → Package | 62/100 | **80/100** | 85/100 | 95/100 |
| **Overall** | **62/100** | **75/100** | **87/100** | **95/100** |

---

## Key Findings

### 1. Hierarchy Matters
Slides make clear: **correlation is THE functional**. Not one of many equals.

### 2. Framing Matters
Slides emphasize **X-level vs Obs-level** (compositional vs general). Paper emphasizes TV vs Wasserstein (which are secondary choices within each geometry).

### 3. Paradigm Matters
CATE covariance is **within-study** (heterogeneity in one population). Core method is **across-study** (transportability across populations). Different questions.

### 4. Inference Matters
Slides present **frequentist functional delta method**. Bayesian bootstrap is an alternative, not the method.

---

## Critical Gaps (Must Fix)

### Paper Missing PTE Misleading Example
**Problem:** Slide 13 shows key example where PTE = 0.54 but correlation = 0.00
**Impact:** This is THE motivating example for why the method is needed
**Fix:** Add simulation scenario to paper with figure
**Priority:** HIGH

### Wrong Emphasis in Paper
**Problem:** Paper emphasizes TV vs Wasserstein; slides emphasize X-level vs Obs-level
**Impact:** Readers misunderstand what the key choice is
**Fix:** Restructure geometry discussion
**Priority:** HIGH

### Unmarked Experimental Functions
**Problem:** Package has 6 functionals, all appearing equal
**Impact:** Users don't know correlation is THE functional
**Fix:** Add experimental notes to 5 functions
**Priority:** CRITICAL

---

## FAQ

### Q: Will this break existing code?
**A:** No. All functions remain available and work the same. Only documentation changes.

### Q: Why deprecate working functions?
**A:** We're not removing them, just clarifying they're experimental/alternative. Users can still use them.

### Q: What if I prefer concordance/PPV/Bayesian inference?
**A:** Use them! But documentation will clarify these are alternatives to the core method.

### Q: How long will implementation take?
**A:** 14-19 hours total across three priorities. Can be split across sessions.

### Q: When should this be done?
**A:** Priority 1 before next paper submission. Priority 2 before preprint. Priority 3 before final submission.

---

## Quick Start: Next Steps

### For Implementer
1. Read `IMPLEMENTATION_GUIDE.md` fully
2. Start with Priority 1, Task 1.1 (concordance functional)
3. Work through checklist sequentially
4. Verify after each task

### For Reviewer
1. Read `DEPRECATIONS.md` for complete strategy
2. Review `SLIDES_VS_PAPER_VS_PACKAGE.md` for gaps
3. Approve/modify Priority 1 plan
4. Sign off on paper changes

### For User (Current Package Users)
1. No action needed immediately
2. When documentation updates, read new README
3. Core workflow unchanged (correlation functional works same)
4. New help text clarifies which functions are core vs experimental

---

## Success Criteria

✅ **Users know what the core method is** (correlation, X-level vs Obs-level)
✅ **Paper and slides tell same story** (emphasis, examples, framing)
✅ **Package documentation clarifies hierarchy** (core vs experimental)
✅ **No breaking changes** (all code still works)
✅ **Improved onboarding** (new users see clear workflow)
✅ **Better reviews** (consistent vision across materials)

---

## Contact for Questions

- See `DEPRECATIONS.md` for comprehensive FAQ
- See `IMPLEMENTATION_GUIDE.md` for technical questions
- See `SLIDES_VS_PAPER_VS_PACKAGE.md` for specific component status

---

**Status:** Planning phase complete. Ready to begin Priority 1 implementation.

**Estimated completion:**
- Priority 1: 1 week (4-6 hours)
- Priority 2: 2 weeks (8-10 hours)
- Priority 3: 3-4 days (2-3 hours)
- **Total: 3-4 weeks part-time or 1 week full-time**
