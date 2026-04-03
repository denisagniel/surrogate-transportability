# Revision Notes: Focus on Correct Method

**Date:** 2026-03-24 (Revision)
**Reason:** Remove bootstrap comparisons from manuscript

---

## What Changed

Per user feedback: "We don't need to compare against bootstrap. That didn't work, we should note it in our internal notes, but we don't have to mention it in the paper or compare against it in simulations."

**Rationale:** Bootstrap was an implementation bug, not a competing method. The paper should describe the correct reweighting approach without dwelling on what doesn't work.

---

## Manuscript Changes

### Section 3: Minimax bounds
**Before:** "Implementation: Reweighting vs. bootstrap" (~25 lines explaining why bootstrap is wrong)
**After:** "Implementation via deterministic reweighting" (~10 lines describing what we do)

**Key changes:**
- Removed comparisons to bootstrap method
- Removed "17.6x improvement" comparisons
- Focus on describing deterministic reweighting approach
- Note that bootstrap remains appropriate for CI construction

### Section 5: Simulation study
**Before:** "reweighting-based minimax approach"
**After:** Simply "minimax approach"

**Removed:** All mentions of bootstrap comparisons in results

### Section 6: Theoretical properties
**Before:** "This is 17.6× better than bootstrap-based methods"
**After:** Focus on absolute performance (<2% error)

**Key changes:**
- Report approximation quality without comparison
- Focus on convergence properties
- Emphasize what works, not what doesn't

---

## Code Changes

### Validation Scripts
**Changed:** Header comments to focus on validation goal, not method comparison

**validate_rf_ensemble_theory.R:**
- Removed "17.6x improvement" from header
- Focus on "tests theorem: RF-ensemble → TV-ball minimax"
- Describe method as "deterministic reweighting"

**multi_discretization_minimax.R:**
- Similar header updates
- Focus on multi-scheme ensemble approach

### Internal Documentation Only

**compare_reweighting_vs_bootstrap.R:**
- Marked as **internal documentation only**
- Purpose: Validate correctness, document the bug for our records
- **NOT for manuscript or publication**

---

## Documentation Changes

### IMPLEMENTATION_SUMMARY.md
Updated to focus on positive results:
- Approximation quality table: Shows reweighting results only
- Convergence table: Shows single column (not comparison)
- "What Changed" → "Theoretical Framework Established"
- Removed bootstrap from implementation recommendations
- Updated lessons learned to focus on correct method

### Session Notes
- Noted bootstrap comparison is internal only
- Updated remaining work to focus on validation, not comparison
- Clarified manuscript status (14 pages, bootstrap removed)

---

## Final Manuscript Structure

**14 pages, structured as:**
1. Introduction
2. Setting (with treatment effect heterogeneity discussion)
3. Minimax bounds (with deterministic reweighting implementation)
4. Inference for ε-close statements
5. Simulation study (with validation results)
6. Theoretical properties (RF-ensemble approximation theorem)

**No mention of bootstrap** in main text. Paper describes what we do (reweighting) and why it works (approximates TV-ball minimax with <2% error).

---

## Internal Notes (Not for Paper)

**For our records:** Bootstrap sampling was tested early in development and found to introduce unnecessary sampling variability, resulting in ~22% average error compared to ~1.3% with reweighting. This was an implementation issue, not a methodological question. The correct approach is deterministic reweighting to explore distribution space, with bootstrap reserved for CI construction. This is documented in:

- Session notes (2026-03-23 evening)
- compare_reweighting_vs_bootstrap.R (internal validation)
- Early versions of validation scripts (before correction)

**Key learning:** For minimax estimation (finding worst-case Q), use deterministic evaluation. For uncertainty quantification (CIs), use bootstrap.

---

## Verification

- ✅ Manuscript compiles (14 pages, no errors)
- ✅ All bootstrap comparisons removed from main text
- ✅ Implementation section describes reweighting clearly
- ✅ Validation scripts focus on approximation quality
- ✅ Internal documentation preserved for our records

---

## Next Steps

Unchanged from before:
1. Run validation scripts to generate results
2. Create convergence and approximation plots
3. Generate ensemble comparison plots
4. Create supplement with formal proofs
5. Submit for publication

The manuscript now focuses entirely on the correct method and its theoretical properties, without comparing against a broken approach.
