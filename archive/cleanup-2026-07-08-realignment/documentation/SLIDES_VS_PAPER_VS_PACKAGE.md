# Slides vs Paper vs Package: Detailed Comparison

**Date:** 2026-05-01
**Purpose:** Quick reference for alignment status

---

## Legend
- ✅ **Present and emphasized**
- ⚠️ **Present but de-emphasized or different framing**
- ❌ **Absent or minimal mention**
- 🔧 **Internal/computational only**

---

## Functionals

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Correlation** | ✅ PRIMARY | ⚠️ Equal weight | ✅ Implemented | **CORE** | Emphasize in paper |
| **R-squared** | ✅ Example | ⚠️ Mentioned | ❌ Not implemented | SECONDARY | Document as example |
| **MSPE** | ✅ Example | ⚠️ Mentioned | ❌ Not implemented | SECONDARY | Document as example |
| **Concordance** | ❌ Absent | ❌ Absent | ✅ Implemented | EXPERIMENTAL | Flag as experimental |
| **PPV** | ❌ Absent | ❌ Absent | ✅ Implemented | EXPERIMENTAL | Flag as experimental |
| **NPV** | ❌ Absent | ❌ Absent | ✅ Implemented | EXPERIMENTAL | Flag as experimental |
| **Conditional Mean** | ❌ Removed | ⚠️ Mentioned (line 81) | ✅ Implemented | EXPERIMENTAL | Flag as experimental |
| **Probability** | ❌ Absent | ⚠️ Mentioned (line 81) | ✅ Implemented | EXPERIMENTAL | Flag as experimental |
| **CATE Covariance** | ❌ Absent | ❌ Absent | ✅ Full file | ALTERNATIVE | Flag as alt paradigm |

---

## Geometries

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **X-level (Compositional)** | ✅ PRIMARY FRAMING | ⚠️ Mentioned | ✅ Implemented | **CORE** | Strengthen in paper |
| **Obs-level (General)** | ✅ PRIMARY FRAMING | ⚠️ Mentioned | ✅ Implemented | **CORE** | Strengthen in paper |
| **Complementary analysis** | ✅ "Report both" | ❌ Not emphasized | ⚠️ Both available | **CORE** | Emphasize in paper |
| **TV vs Wasserstein emphasis** | ⚠️ Secondary | ✅ PRIMARY FRAMING | ✅ Implemented | ALIGNMENT GAP | Reframe paper |

---

## Distance Metrics

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **TV (Total Variation)** | ✅ Emphasized | ✅ Primary | ✅ Implemented | **CORE** | Keep |
| **Wasserstein** | ✅ Emphasized | ✅ Primary | ✅ Implemented | **CORE** | Keep |
| **KL Divergence** | ❌ Absent | ⚠️ Mentioned (line 96) | ❌ Not implemented | FUTURE WORK | Move to future directions |
| **Chi-squared** | ❌ Absent | ⚠️ Mentioned (line 97) | ❌ Not implemented | FUTURE WORK | Move to future directions |
| **L2 Distance** | ❌ Absent | ⚠️ Mentioned (line 98) | ❌ Not implemented | FUTURE WORK | Move to future directions |

---

## Sampling and Inference

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Hit-and-run MCMC** | ✅ Explained (Slide 14) | ✅ Detailed | ✅ Implemented | **CORE** | Keep |
| **Uniform distribution on geometry** | ✅ Emphasized | ✅ Detailed | ✅ Implemented | **CORE** | Keep |
| **Two-stage inference** | ✅ AIPW + delta method | ✅ Detailed | ✅ Implemented | **CORE** | Keep |
| **Functional delta method** | ✅ Emphasized (Slide 15) | ✅ Detailed | ✅ `wasserstein_minimax_IF_inference()` | **CORE** | Keep |
| **Bayesian bootstrap** | ❌ Absent | ❌ Absent | ✅ `posterior_inference()` | ALTERNATIVE | Flag as alternative |
| **Sample splitting** | ❌ Absent | ❌ Absent | ✅ Implemented | ADVANCED | Flag as advanced |

---

## Conceptual Framework

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Absolute continuity (Q << P₀)** | ✅ "Practical choice" (Slide 12) | ✅ Detailed | ✅ Enforced | **CORE** | Keep |
| **Local geometries** | ✅ Central concept | ✅ Central concept | ✅ Implemented | **CORE** | Keep |
| **Lambda parameter** | ✅ "Grid search 0.05-0.20" | ✅ Detailed | ✅ Implemented | **CORE** | Keep |
| **Flat vs steep interpretation** | ✅ "Robust vs fragile" | ⚠️ Less emphasized | ⚠️ Plots available | **CORE** | Emphasize in paper |

---

## Comparisons (Background Methods)

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Mediation / PTE** | ✅ Slide 6 (critique) | ✅ Introduction | ✅ `compute_pte_standard()` | **COMPARISON** | Keep |
| **Principal Stratification** | ✅ Slide 7 (critique) | ✅ Introduction | ✅ `compute_ps_standard()` | **COMPARISON** | Keep |
| **Meta-analysis** | ✅ Slide 8 (gold standard) | ✅ Introduction | ❌ Not needed | **COMPARISON** | Keep in paper |
| **PTE misleading example** | ✅ Slide 13 (key example) | ❌ ABSENT | ⚠️ Data generator exists | CRITICAL GAP | **ADD TO PAPER** |

---

## Computational Approaches

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Type-level discretization** | ❌ Not mentioned | ⚠️ May be in Section 9 | ✅ Implemented | INTERNAL | Keep as internal |
| **Closed-form solutions** | ❌ Not mentioned | ⚠️ May be in Section 9 | ✅ For concordance | INTERNAL | Keep as internal |
| **9x TV speedup** | ❌ Not mentioned | ⚠️ May be documented | 🔧 Optimized | INTERNAL | Keep quiet |
| **487x Wasserstein speedup** | ❌ Not mentioned | ⚠️ May be documented | 🔧 Optimized | INTERNAL | Keep quiet |
| **RF-ensemble discretization** | ❌ Not mentioned | ⚠️ Section 9 (~70 pages) | ⚠️ May be implemented | DEPRECATE | Move to supplement |

---

## Simulation Studies

| Component | Slides | Paper | Package | Status | Action |
|-----------|--------|-------|---------|--------|--------|
| **Study 1** | ⚠️ Results mentioned | ✅ Detailed (71% vs 38-49%) | ✅ DGP exists | KEEP | Keep |
| **Opposite-signed interactions** | ✅ Slide 13 (key example) | ❌ ABSENT | ⚠️ Can generate | CRITICAL GAP | **ADD TO PAPER** |
| **Study 2 placeholder** | ❌ Not mentioned | ⚠️ Lines ~781-785 | ❌ Not implemented | DEPRECATE | Complete or remove |
| **Study 3 placeholder** | ❌ Not mentioned | ⚠️ Lines ~781-785 | ❌ Not implemented | DEPRECATE | Complete or remove |

---

## Key Alignment Gaps

### Critical Gaps (Fix Immediately)
1. **PTE Misleading Example Missing from Paper** - Slides Slide 13 is a key example, paper doesn't have it
2. **X-level vs Obs-level Framing Weak in Paper** - Paper emphasizes TV vs Wasserstein instead
3. **Correlation Not Emphasized as Primary** - Paper treats all functionals equally
4. **Studies 2-3 Are Placeholders** - Can't submit with incomplete sections

### Important Gaps (Fix Soon)
1. **Flat vs Steep Interpretation** - Slides emphasize this, paper less so
2. **Report Both Analyses** - Slides say "report both X-level and Obs-level", paper doesn't emphasize
3. **Alternative Functionals Unmarked** - Package has concordance, PPV, NPV, conditional mean without experimental notes
4. **Bayesian Inference Unmarked** - Package has full Bayesian approach not mentioned in slides

### Minor Gaps (Fix When Convenient)
1. **R-squared and MSPE Not Implemented** - Mentioned in slides as examples, could add
2. **KL/Chi-squared/L2 Not in Future Work** - Mentioned in paper but not framed as future work
3. **RF-Ensemble in Main Paper** - Should be supplement if kept at all

---

## Verification: Does Each Component Match Slides?

### Perfect Alignment ✅
- Hit-and-run MCMC
- Two-stage inference (AIPW + delta method)
- Absolute continuity restriction
- Local geometries concept
- TV and Wasserstein metrics
- Traditional method comparisons

### Needs Emphasis Shift ⚠️
- Correlation as PRIMARY functional (paper treats equally)
- X-level vs Obs-level as PRIMARY distinction (paper emphasizes TV vs Wasserstein)
- Flat vs steep interpretation (paper less clear)
- Complementary analyses (paper doesn't say "report both")

### Needs Flagging/Deprecation ❌
- Concordance functional (not in slides → experimental)
- PPV/NPV functionals (not in slides → experimental)
- Conditional mean functional (removed from slides → experimental)
- CATE covariance (different paradigm → alternative)
- Bayesian inference (not in slides → alternative)
- Sample splitting (not in slides → advanced)
- RF-ensemble (not in slides → supplement)
- Studies 2-3 (not in slides → deprecate)

### Critical Additions Needed 🔴
- PTE misleading example (Slide 13) → ADD TO PAPER
- X-level vs Obs-level framing → STRENGTHEN IN PAPER
- Correlation hierarchy → EMPHASIZE IN PAPER

---

## Summary Statistics

### Alignment Scores

**Slides → Paper:**
- Core concepts: 90/100 (good alignment on fundamentals)
- Emphasis: 60/100 (wrong things emphasized - TV vs Wasserstein instead of X-level vs Obs-level)
- Examples: 40/100 (missing key PTE misleading example)
- **Overall: 63/100** - Needs significant reframing

**Slides → Package:**
- Core functions: 95/100 (well implemented)
- Experimental marking: 20/100 (nothing marked experimental)
- Documentation: 70/100 (functions work but hierarchy unclear)
- **Overall: 62/100** - Needs experimental flagging

**Three-Way Alignment:**
- **Current: 62/100** (significant gaps)
- **After Priority 1: 80/100** (core method clear)
- **After Priority 2: 90/100** (paper matches slides)
- **After Priority 3: 95/100** (polish complete)

---

## Quick Action Checklist

### Paper
- [ ] Add PTE misleading example (Slide 13)
- [ ] Emphasize X-level vs Obs-level (Slides 16-19)
- [ ] Lead with correlation functional
- [ ] Add "report both" guidance
- [ ] Complete or remove Studies 2-3
- [ ] Move RF-ensemble to supplement

### Package
- [ ] Flag concordance as experimental
- [ ] Flag PPV/NPV as experimental
- [ ] Flag conditional mean as experimental
- [ ] Flag CATE covariance as alternative paradigm
- [ ] Flag posterior_inference as alternative inference
- [ ] Update README to match slides
- [ ] Update primary vignette to match slides

### Both
- [ ] Verify all cross-references
- [ ] Update NEWS.md
- [ ] Add lifecycle badges
- [ ] Create verification tests

---

**Last Updated:** 2026-05-01
**Next Review:** After Priority 1 implementation
