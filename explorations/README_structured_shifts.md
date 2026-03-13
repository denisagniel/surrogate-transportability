# Structured Shift DGPs for Simulation Validation

**Added:** 2026-03-13
**Purpose:** Test whether innovation approach (μ = Dirichlet(1,...,1)) provides valid inference when true future study mechanism is structured

---

## The Core Question

**You asked:** "What is the space of distributions that we simulate from? Ideally that space would not be exactly the same as μ, right?"

**Exactly.** The current simulations have a circularity issue:
- **Method assumes:** Future studies generated via Q = (1-λ)P₀ + λP̃, P̃ ~ Dirichlet(1,...,1)
- **Current sims test:** Generate futures via... same Dirichlet(1,...,1)
- **Problem:** Only validates math/implementation, not robustness or generalization

**What we need:** Simulate futures from structured mechanisms (≠ Dirichlet), then test if method's inference about φ(F_λ) is still valid.

---

## New DGPs Added

### 1. `generate_covariate_shift_study()`

**What it does:** Pure covariate shift - only P(class) changes, P(S,Y|A,class) stays the same

**Example:**
```r
baseline <- generate_study_data(n=500, class_probs=c(0.5, 0.5), ...)

# Future study shifts toward class 1
future <- generate_covariate_shift_study(
  baseline,
  target_class_probs = c(0.7, 0.3)
)

future$tv_distance  # Computes d_TV(Q, P₀)
```

**Key metrics returned:**
- `tv_distance`: Total variation distance (analytical for class distribution)
- `kl_divergence`: KL divergence between class distributions
- `shift_magnitude`: max|p_new - p_old| over classes

**Use case:** Test robustness to population composition changes (e.g., age, geography, disease severity)

---

### 2. `generate_selection_study()`

**What it does:** Non-random selection from baseline population via selection bias

**Selection types:**
- `outcome_favorable`: Select healthier patients (high Y)
- `outcome_unfavorable`: Select sicker patients (low Y)
- `treatment_responders`: Select high surrogate responders (high S)
- `treatment_nonresponders`: Select low responders (low S)
- `covariate_extreme`: Select extreme covariate values (high |X|)
- `custom`: Provide your own selection function

**Example:**
```r
# Future study selects treatment responders
future <- generate_selection_study(
  baseline,
  selection_type = "treatment_responders",
  selection_strength = 0.7  # 0=uniform, 1=maximum bias
)

future$effective_sample_size  # ESS measures selection bias
```

**Key metrics returned:**
- `effective_sample_size`: 1/Σ(weights²), measures concentration
- `tv_distance_estimate`: Monte Carlo approximation of d_TV
- `selection_weights`: Probability of selecting each baseline observation

**Use case:** Test robustness to referral bias, volunteer effects, loss-to-follow-up

---

### 3. `tv_distance_empirical()`

**What it does:** Computes d_TV(P̂₁, P̂₂) between two empirical distributions

**Example:**
```r
data1 <- generate_study_data(class_probs = c(0.5, 0.5), ...)
data2 <- generate_study_data(class_probs = c(0.7, 0.3), ...)

tv <- tv_distance_empirical(data1, data2, variables = c("A", "S", "Y"))
```

**Use case:** Empirically measure how far future studies are from baseline

---

## How This Answers Your Question

### What Space Does μ = Dirichlet(1,...,1) Cover?

**Interpretation:** Uniform Dirichlet is maximum entropy → averages over **all possible** perturbations within distance λ.

**Key insight:**
- If **truth** is covariate shift, some Dirichlet draws will produce covariate-shift-like futures
- If **truth** is selection, some Dirichlet draws will mimic that
- Dirichlet(1,...,1) is like taking expectation over all mechanisms

**What simulations will show:**
> When truth = [structured mechanism], φ(F_λ) under Dirichlet(1,...,1) should:
> - Bracket the true surrogate quality (conservative/liberal?)
> - Provide correct coverage (CI contains truth?)
> - Degrade gracefully as mechanism diverges from uniform

---

## Proposed Simulation Design

### Simulation 1: Covariate Shift Coverage

**Pseudocode:**
```r
# Generate baseline
P0 <- generate_study_data(class_probs = c(0.5, 0.5))

# TRUE future studies (covariate shift)
true_futures <- list(
  Q1 = generate_covariate_shift_study(P0, c(0.6, 0.4)),
  Q2 = generate_covariate_shift_study(P0, c(0.7, 0.3)),
  Q3 = generate_covariate_shift_study(P0, c(0.8, 0.2))
)

# Compute TRUE φ(Qi) for each future study
true_phi <- map(true_futures, ~{
  compute_treatment_effects(...) %>%
  functional_correlation()
})

# Compute TRUE λi = d_TV(Qi, P0)
true_lambda <- map(true_futures, ~tv_distance_empirical(., P0))

# Apply METHOD (assumes Dirichlet)
method_results <- map(true_lambda, ~{
  posterior_inference(P0, lambda = ., innovation_type = "bayesian_bootstrap")
})

# CHECK COVERAGE
coverage <- map2(true_phi, method_results, ~{
  .x >= .y$summary$lower_ci && .x <= .y$summary$upper_ci
})

# CLAIM: "Method provides 95% coverage for covariate shifts with λ ≤ X"
```

**What this tells us:**
- Is the method conservative (CI too wide) or liberal (too narrow)?
- What λ values maintain valid inference under covariate shift?
- Can we claim "robust to population composition changes of ±Y%"?

---

### Simulation 2: Selection Bias Robustness

**Pseudocode:**
```r
# TRUE futures (selection mechanisms)
selection_strengths <- c(0.3, 0.5, 0.7)

for (strength in selection_strengths) {
  true_futures <- replicate(100, {
    generate_selection_study(P0, type="outcome_favorable", strength=strength)
  })

  # Compute true φ
  true_phi_dist <- map(true_futures, ~functional_correlation(...))

  # Apply method (assumes Dirichlet)
  # Use λ = mean TV distance of selected studies
  lambda_est <- mean(map_dbl(true_futures, ~.$tv_distance_estimate))
  method_result <- posterior_inference(P0, lambda = lambda_est)

  # Check if method CI covers mean(true_phi_dist)
  coverage[strength] <- ...
}

# CLAIM: "Method handles selection bias up to ESS = Z"
```

**What this tells us:**
- When does selection bias break the Dirichlet assumption?
- Is there a threshold (ESS, selection_strength) beyond which inference fails?

---

### Simulation 3: Misspecification Sensitivity

**Test:** What if truth is Dirichlet(α) but we assume Dirichlet(1)?

```r
true_alpha_values <- c(0.1, 1, 5, 10, 50)

for (alpha in true_alpha_values) {
  # Generate true futures with concentrated Dirichlet(α)
  true_futures <- replicate(100, {
    # Use modified generate_future_study with custom α
    ...
  })

  # Apply method (assumes α=1)
  method_result <- posterior_inference(P0, ...)

  # Check coverage
  ...
}
```

**What this tells us:**
- How robust is the method to misspecification of μ?
- Should we report results for multiple μ values (as paper suggests)?

---

## Theoretical Extensions This Enables

### 1. Characterize Robustness Classes

**Proposition [simulation-based]:**
> The innovation approach with μ = Dirichlet(1,...,1) provides valid inference (95% coverage) for:
> - Covariate shift with Δclass_probs ≤ [X]
> - Selection bias with ESS ≥ [Y]
> - Combined shifts with d_TV(Q,P₀) ≤ [λ*]

### 2. Substantive Interpretation of λ

**Example claims:**
> "λ = 0.2 accommodates:
>  - Population shifts where class proportions change by ±15%
>  - Selection bias with effective sample size ≥ 300 (out of n=500)
>  - Covariate shifts equivalent to [describe in domain terms]"

### 3. Comparison to Transportability Literature

**Structured transportability assumptions:**
- Covariate shift only: P(X) changes, P(Y|X,A) fixed
- Selection diagrams: S-admissibility, back-door, front-door

**Our approach:**
- More general: allows shifts in full joint P(X,A,S,Y)
- Less structured: no assumptions on mechanism
- Tradeoff: generality vs. efficiency

**Can show:** "When truth is pure covariate shift, our approach is [conservative/valid/...] compared to covariate-shift-only methods"

---

## Next Steps

### Immediate (Code):
1. ✅ Add new DGPs to `data_generators.R` - DONE
2. ✅ Write tests - DONE (56 tests pass)
3. ✅ Create example script - DONE
4. Create simulation scripts in `sims/scripts/`:
   - `08_covariate_shift_validation.R`
   - `09_selection_bias_validation.R`
   - `10_dirichlet_misspecification.R`

### Short-term (Analysis):
5. Run structured shift simulations
6. Generate coverage plots (λ vs coverage rate)
7. Create summary tables for paper

### Medium-term (Theory):
8. Derive sufficient conditions for robustness
9. Characterize Lipschitz constants explicitly
10. Compare worst-case vs average-case bounds

### Paper (Section 5):
11. Add simulation subsection: "Validation under structured shifts"
12. Add remark after Theorem 1: "Robustness to mechanism misspecification"
13. Add Figure: "Coverage rates under covariate shift and selection"

---

## Files Added

**Package code:**
- `package/R/data_generators.R`: Three new exported functions (lines 239-637)

**Tests:**
- `package/tests/testthat/test-structured-shifts.R`: 56 tests, all passing

**Documentation:**
- `package/man/generate_covariate_shift_study.Rd`: Auto-generated
- `package/man/generate_selection_study.Rd`: Auto-generated
- `package/man/tv_distance_empirical.Rd`: Auto-generated

**Examples:**
- `explorations/structured_shift_examples.R`: Runnable demonstrations
- `explorations/README_structured_shifts.md`: This file

---

## Key Takeaway

**Your intuition was exactly right:** We need to simulate from a space ≠ μ to truly validate the method.

**What we've built:** DGPs that create structured future studies (covariate shift, selection bias) so we can test:
1. Does φ(F_λ) under Dirichlet(1,...,1) provide valid inference when truth is structured?
2. What classes of mechanisms does the uniform Dirichlet cover?
3. When does the method break down?

**This allows the paper to claim:** "Method is robust to [specific mechanisms] within distance λ = [bound]" rather than just "method works when assumptions hold".
