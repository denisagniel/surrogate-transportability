# Validation Studies Overview

**Purpose:** Assess whether the innovation approach provides valid statistical inference when future studies arise from specific structured mechanisms (rather than generic Dirichlet perturbations).

**Key Innovation:** The method assumes future studies Q arise from a mixture distribution Q = (1-λ)P₀ + λP̃ where P̃ ~ Dirichlet(1,...,1). But what if the TRUE mechanism is something else entirely?

---

## Conceptual Framework

### The Method's Claim
The innovation approach estimates E[φ(F_λ)] where F_λ is the distribution of future studies within TV distance λ of P₀, when innovations come from Dirichlet(1,...,1).

It provides:
- **Point estimate:** mean surrogate quality across future studies
- **Confidence interval:** for the mean E[φ(F_λ)]
- **Quantile interval:** 95% range for a single future study φ(Q)

### The Validation Question
**Does this approach provide valid coverage when the TRUE mechanism generating futures is NOT Dirichlet perturbations?**

Three structured mechanisms are tested:

---

## Study 1: Covariate Shift Validation

### What It Tests
**TRUE mechanism:** Future studies differ ONLY in covariate distributions.
- Baseline: 50% class A, 50% class B
- Future: Shift to 60/40, 70/30, 80/20, or 90/10
- **Critical:** P(S,Y|A,class) stays FIXED across studies
- Only P(class) changes → pure covariate shift

### Why It Matters
**Real-world scenario:** Different populations enrolled in future trials.
- Original study: 50% low-risk, 50% high-risk patients
- Future study: 70% low-risk, 30% high-risk patients (healthier population)

**Question:** Does the method's CI cover the TRUE surrogate quality in the shifted population?

### What We Test
- **4 scenarios:** Small (60/40), Moderate (70/30), Large (80/20), Extreme (90/10)
- **Measure:** λ = TV distance from baseline (ranges 0.1 to 0.4)
- **1,000 replications per scenario**

### Interpretation
- **If coverage ≥ 95%:** Method is robust to covariate shift within λ ≤ 0.4
- **If coverage < 95%:** Method breaks down when shift is too extreme
- **Connection to λ:** Shows how large a covariate shift corresponds to specific λ values

---

## Study 2: Selection Bias Validation

### What It Tests
**TRUE mechanism:** Future studies are selected subsets of the population.
- Baseline: Random sample from full population
- Future: Selected based on outcomes or treatment response

**Selection types:**
1. **Outcome-favorable:** Select individuals with better outcomes (e.g., healthier patients)
2. **Treatment-responders:** Select individuals who respond well to treatment

### Why It Matters
**Real-world scenario:** Future studies may have implicit selection.
- Healthier patients → outcome-favorable selection
- Willing volunteers → treatment-responder selection
- Post-market surveillance → survivor bias

**Question:** Does the method's CI cover the TRUE surrogate quality when selection occurs?

### What We Test
- **4 scenarios:**
  - Weak outcome-favorable (30% selection strength)
  - Moderate outcome-favorable (60%)
  - Strong outcome-favorable (90%)
  - Moderate treatment-responders (60%)
- **Measure:** Effective sample size (ESS) as proxy for selection severity
- **1,000 replications per scenario**

### Interpretation
- **If coverage ≥ 95%:** Method is robust to moderate selection bias
- **If coverage < 95%:** Method breaks down under strong selection
- **Connection to ESS:** Shows minimum ESS needed for valid inference

---

## Study 3: Dirichlet Misspecification

### What It Tests
**TRUE mechanism:** Innovations come from Dirichlet(α) with α ≠ 1.
- Method assumes: P̃ ~ Dirichlet(1,...,1) (uniform over simplex)
- Truth: P̃ ~ Dirichlet(α,...,α) for α ∈ {0.1, 0.5, 1.0, 2.0, 5.0, 10.0}

**What α controls:**
- **α = 1:** Uniform (correctly specified) → Bayesian bootstrap
- **α < 1:** Concentrated toward boundaries (sparse, extreme weights)
- **α > 1:** Concentrated toward center (diffuse, more uniform)

### Why It Matters
**Theoretical question:** Is the method robust to HOW futures are distributed within the λ-ball?

The TV constraint says ‖Q - P₀‖_TV ≤ λ, but there are many distributions Q satisfying this. Does it matter which ones are sampled?

**Practical implication:** If robust to α misspecification, the λ constraint is more fundamental than the specific innovation distribution.

### What We Test
- **6 scenarios:** α ∈ {0.1, 0.5, 1.0, 2.0, 5.0, 10.0}
- **Fixed λ = 0.2** (moderate perturbation)
- **1,000 replications per scenario**

### Interpretation
- **If coverage ≥ 95% for all α:** Method is robust to innovation distribution form
- **If coverage varies with α:** Method is sensitive to how futures are distributed
- **Theoretical insight:** Tests whether λ constraint alone guarantees valid inference

---

## Overall Design

### Monte Carlo Framework
Each replication:
1. **Generate baseline study** (n=1,000)
2. **Generate TRUE futures** from structured mechanism (500 studies)
3. **Compute TRUE φ(Q)** = correlation between δ_S and δ_Y
4. **Apply METHOD** with nested bootstrap:
   - 500 baseline resamples (for CI stability)
   - 500 draws from F_λ
   - 200 MC draws per bootstrap
   - Total: 50M samples per replication
5. **Check coverage:** Does METHOD CI contain TRUE φ(Q)?

### Coverage Assessment
- **Target:** 95% CI coverage
- **Acceptable:** ≥ 90% coverage (accounting for Monte Carlo error)
- **Standard error:** SE ≈ √(0.95×0.05/1000) ≈ 0.007 per scenario

With 1,000 replications, we can reliably detect:
- 5% departures from nominal coverage
- Differences between scenarios

---

## What These Studies Tell Us

### If All Three Validate (Coverage ≥ 95%):
✅ Method is robust to:
- Covariate distribution shifts up to λ ≈ 0.3-0.4
- Moderate selection bias (ESS ≥ 500)
- Innovation distribution misspecification (any α)

**Implication:** The λ constraint is sufficient. As long as ‖Q - P₀‖_TV ≤ λ, inference is valid regardless of HOW the shift occurs.

### If Some Fail (Coverage < 90%):
⚠ Method has limitations:
- Identify specific scenarios where method breaks
- Characterize safe operating range (e.g., λ ≤ 0.2)
- Recommend cautions for practitioners

**Value:** Honest assessment of method boundaries.

### Connection to Paper
These validation studies provide:
- **Section 5.X:** Empirical validation under structured shifts
- **Figure X:** Coverage plots by scenario type
- **Table X:** Coverage rates and CI widths
- **Discussion:** Method robustness and practical guidance

**Key claim:** "The method maintains nominal coverage under [specify scenarios], demonstrating robustness to diverse future study mechanisms within the λ-constrained space."

---

## Computational Scale

**Current parameters (updated):**
- n_baseline_resamples: 500 (for stable CI)
- n_bootstrap: 500 (for F_λ estimation)
- n_mc_draws: 200 (for φ estimation)
- **Total samples:** 50,000,000 per replication

**Total scale:**
- 14 scenarios × 1,000 reps = 14,000 replications
- 50M samples × 14,000 reps = 700 trillion samples
- ~14 hours per replication on O2
- ~200,000 core-hours total

**Why so many samples?**
The nested bootstrap CI requires hundreds of baseline resamples to achieve stable 95% coverage. Initial runs with 100 resamples achieved only 88.4% coverage.

---

## Interpretation Framework

### For Each Study, Report:
1. **Coverage rate** by scenario (target: ≥95%)
2. **CI width** (narrower is better, if valid)
3. **Bias** (method estimate vs. true φ)
4. **Calibration plots** (estimated vs. true φ)

### Cross-Study Comparisons:
- Which mechanism is most challenging?
- What λ values are safe?
- Are quantile intervals always conservative?

### For the Paper:
- **If all validate:** Emphasize robustness across mechanisms
- **If some fail:** Characterize safe operating range
- **Either way:** Provides honest empirical assessment beyond theory

---

## Quick Reference

| Study | Scenarios | Question | Key Metric |
|-------|-----------|----------|------------|
| Covariate Shift | 4 | Does covariate shift break inference? | λ (TV distance) |
| Selection Bias | 4 | Does selection break inference? | ESS (effective sample size) |
| Dirichlet Misspec | 6 | Does innovation form matter? | α (concentration parameter) |

**Total:** 14 scenarios × 1,000 reps = 14,000 replications

**Output:** Coverage rates, calibration plots, CI widths → Section 5.X of paper

**Key Innovation:** Goes beyond theory to empirically test method robustness under realistic future study mechanisms.
