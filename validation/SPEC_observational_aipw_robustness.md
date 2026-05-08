# Specification: Observational AIPW Robustness Simulation

**Date:** 2026-05-08
**Status:** REVISED
**Purpose:** Assess robustness of AIPW-based correlation inference to nuisance function misspecification and test asymptotic convergence rates

---

## Executive Summary

Design and implement a simulation study comparing:
1. **Oracle AIPW:** Uses true propensity score e(X) and true outcome regressions μ_a(X)
2. **Estimated AIPW:** Uses estimated nuisances (true + noise) with varying noise levels

This will quantify how estimation error in nuisances affects bias, variance, and coverage of the correlation functional ρ across TV ball.

---

## Background

### Current Status
- Have RCT-only implementation: `tv_ball_correlation_IF()` with `method = "importance_weighting"`
- Assumes e(X) = 0.5 (known), no outcome regressions needed
- AIPW method exists but uses cross-fitting (expensive, ~500 model fits per replication)

### Gap
**Unknown:** How robust is AIPW-based correlation inference to nuisance misspecification?
- If e(X) estimate is slightly wrong, does ρ̂ become biased?
- If μ_a(X) estimates have noise, how much does coverage degrade?
- What level of nuisance quality is "good enough" for valid inference?

### Why This Matters
- Observational studies require nuisance estimation
- Perfect nuisance estimation is impossible in practice
- Need to know when AIPW-based correlation inference breaks down
- Informs guidance for practitioners (sample size, model complexity recommendations)

---

## Asymptotic Theory Motivation

### Expected Behavior Under Theory

**AIPW is doubly robust:** If either e(X) or μ_a(X) estimated at rate n^(-α) with α > 0.25, then:
- ρ̂ remains √n-consistent
- Asymptotic variance = σ²(μ_M)/n
- Coverage → 95% as n → ∞

**Product of convergence rates:** For AIPW, what matters is the **product** of rates:
- If α_e · α_μ > 0.25, double robustness kicks in
- If α_e + α_μ > 0.5, first-order bias vanishes
- Slower convergence → larger finite-sample bias

**Fixed noise (α = 0):** Bias does not vanish as n → ∞
- ρ̂ converges to wrong limit
- Coverage breaks down at all n
- Tests that theory fails without sufficient convergence

### What We Should Observe

**Oracle (Scenario 0):**
- Bias ≈ 0 for all n
- Coverage ≈ 95% for all n
- SE ∝ 1/√n

**Slow convergence (α = 0.25):**
- Bias shrinks slowly with n
- May need very large n for coverage
- Finite-sample bias substantial

**Standard rate (α = 0.5):**
- Bias = O(n^(-0.5)) → vanishes like 1/√n
- Coverage good for n ≥ 1000
- Matches typical nonparametric estimation rates

**Fast convergence (α = 0.75):**
- Bias = O(n^(-0.75)) → vanishes faster than 1/√n
- Coverage excellent even at n = 500
- Theory predicts: indistinguishable from oracle for large n

## Research Questions

**RQ1 (Theory Check):** Does oracle AIPW recover true correlation unbiasedly?
- **Metric:** |E[ρ̂_oracle] - ρ_true| < 0.05 for all n
- **Expected:** Yes (validates implementation)

**RQ2 (Convergence Rates):** How does convergence rate α affect bias as function of n?
- **Metric:** Plot |bias| vs n for each α
- **Expected:** Bias ∝ n^(-α) for propensity/outcome alone, depends on α_e + α_μ for both

**RQ3 (Coverage Breakdown):** At what (n, α) combinations does coverage break down?
- **Metric:** Coverage < 93%
- **Expected:** Fixed noise (α=0) fails all n; α=0.25 needs large n; α≥0.5 works at moderate n

**RQ4 (Double Robustness):** Does α_e + α_μ > 0.5 rule hold empirically?
- **Design:** Scenario 3 grid of (α_e, α_μ)
- **Expected:** Regions where α_e + α_μ > 0.5 have good coverage, others fail

**RQ5 (Noise Magnitude):** How does constant c affect finite-sample bias?
- **Design:** Vary c ∈ {0.5, 1.0, 2.0} holding α fixed
- **Expected:** Larger c → larger bias, but rate α determines whether bias vanishes

**RQ6 (Confounding Interaction):** Does confounding strength affect robustness to nuisance noise?
- **Design:** Compare α₁ = 0 (RCT) vs α₁ = 0.6 (strong confounding)
- **Expected:** Stronger confounding → more sensitive to propensity misspecification

---

## Simulation Design

### Data Generating Process

**Use existing DGP 1** (5-level discrete X):
- X ∈ {-2, -1, 0, 1, 2} with P₀ = [0.05, 0.25, 0.40, 0.25, 0.05]
- Structural equations from `cluster/config/dgp_specifications.yaml`
- True ρ = 0.691 (moderate positive correlation)

**Observational twist:** Add **confounding** via non-constant propensity score

**True propensity score:**
```
e(X) = expit(α₀ + α₁·X)
```
where:
- α₀ = 0 (logit scale intercept → overall prevalence ≈ 50%)
- α₁ ∈ {0, 0.3, 0.6} (confounding strength)
  - α₁ = 0: RCT (e = 0.5 for all X)
  - α₁ = 0.3: Mild confounding (e ranges ~0.43 to 0.57)
  - α₁ = 0.6: Strong confounding (e ranges ~0.35 to 0.65)

**True outcome regressions:**
```
μ₁^S(X) = E[S | A=1, X] = γ_A + γ_AX·X
μ₀^S(X) = E[S | A=0, X] = 0

μ₁^Y(X) = E[Y | A=1, X] = β_A + β_AX·X + β_S·(γ_A + γ_AX·X)
μ₀^Y(X) = E[Y | A=0, X] = 0
```
(Deterministic given X in linear model)

### Nuisance Estimation Scenarios

**Key innovation:** Noise scales as **σ(n) = c · n^(-α)** to test asymptotic convergence rates.

**Scenario 0: Oracle (Baseline)**
- Use true e(X), true μ_a^S(X), true μ_a^Y(X)
- No estimation error
- **Purpose:** Establish best-case performance (should match theory regardless of n)

**Scenario 1: Propensity Noise Only**
- e_est(X) = expit(logit(e_true(X)) + ε_e) where ε_e ~ N(0, σ_e(n)²)
- σ_e(n) = c_e · n^(-α_e)
- Use true μ_a^S(X), true μ_a^Y(X)
- **Convergence rates:** α_e ∈ {0, 0.25, 0.5, 0.75}
  - α_e = 0: Fixed noise (no convergence)
  - α_e = 0.5: √n rate (standard for nonparametric estimation)
  - α_e = 0.75: Fast convergence
- **Noise constants:** c_e ∈ {0.5, 1.0, 2.0}
- **Purpose:** Isolate propensity misspecification, test convergence rate requirements

**Scenario 2: Outcome Noise Only**
- Use true e(X)
- μ_est^a(X) = μ_true^a(X) + ε_μ where ε_μ ~ N(0, σ_μ(n)²)
- σ_μ(n) = c_μ · n^(-α_μ)
- **Convergence rates:** α_μ ∈ {0, 0.25, 0.5, 0.75}
- **Noise constants:** c_μ ∈ {0.5, 1.0, 2.0}
- **Purpose:** Isolate outcome regression misspecification, test convergence rate requirements

**Scenario 3: Both Noisy**
- e_est(X) = expit(logit(e_true(X)) + ε_e) with σ_e(n) = c_e · n^(-α_e)
- μ_est^a(X) = μ_true^a(X) + ε_μ with σ_μ(n) = c_μ · n^(-α_μ)
- **Grid:** α_e × α_μ (4×4 = 16 combinations) with c_e = c_μ = 1.0
- **Purpose:** Realistic scenario, identify rate requirements for double robustness

### Simulation Parameters

**Fixed:**
- λ = 0.3 (TV ball radius)
- M = 500 (future studies, may use adaptive M for efficiency)
- α = 0.05 (confidence level)
- N_reps = 500 per setting

**Varied:**
- **Sample size:** n ∈ {500, 1000, 2000, 5000, 10000}
- **Confounding:** α₁ ∈ {0, 0.3, 0.6}
- **Convergence rates:** α_e, α_μ ∈ {0, 0.25, 0.5, 0.75}
- **Noise constants:** c_e, c_μ ∈ {0.5, 1.0, 2.0}

**Total settings:**
- **Scenario 0 (Oracle):** 5 sample sizes × 3 confounding = 15 settings
- **Scenario 1 (Propensity noise):** 5 n × 3 α₁ × 4 α_e × 3 c_e = 180 settings
- **Scenario 2 (Outcome noise):** 5 n × 3 α₁ × 4 α_μ × 3 c_μ = 180 settings
- **Scenario 3 (Both):** 5 n × 3 α₁ × 4 α_e × 4 α_μ = 240 settings
- **Total: 615 settings × 500 reps = 307,500 replications**

**Computational note:** This is large but parallelizable. Can reduce if needed:
- Option A: Fewer reps (200 instead of 500) → 123,000 reps
- Option B: Coarser grid (3 n values, 2 c values) → ~150,000 reps
- Option C: Focus on Scenario 3 only → ~120,000 reps

**Rationale for design:**
- Multiple sample sizes test asymptotic theory (noise should vanish as n → ∞)
- Different α values test convergence rate requirements
- c values test sensitivity to noise magnitude
- Theory predicts: If α_e + α_μ > 0.5, AIPW should be √n-consistent

---

## Implementation Requirements

### MUST (Non-negotiable)

**M1.** Implement observational DGP with confounding
- Add propensity score function to data generator
- Treatment assignment: A ~ Bernoulli(e(X))
- Validate: Empirical e(X) ≈ true e(X) for large n

**M2.** Implement oracle AIPW estimator
- Use true nuisances (no estimation)
- Compute correlation via `tv_ball_correlation_IF()` with `method = "aipw"`
- Verify unbiased for oracle case

**M3.** Implement noisy nuisance generators
- Propensity: Add logit-scale noise, constrain to [0.01, 0.99]
- Outcome regressions: Add noise to predictions
- Reproducible noise (seed per replication)

**M4.** Simulation infrastructure
- Loop over: n, α₁, σ_e, σ_μ
- Compute: ρ̂, SE, CI, coverage
- Save: All settings + results to .rds

**M5.** Analysis and visualization
- Bias vs noise curves (Scenarios 1 & 2)
- Coverage vs noise curves
- Heatmap for Scenario 3 (σ_e × σ_μ grid)
- Compare to oracle baseline

### SHOULD (Strongly Preferred)

**S1.** Use adaptive M for efficiency
- Not all settings may need M=500
- Converge when ρ̂ stable

**S2.** Parallelize simulation
- 168k reps will take hours serially
- Use O2 cluster or local parallel

**S3.** Create diagnostic plots per setting
- Q-Q plot of ρ̂ (check normality)
- Coverage by CI quantile (check calibration)
- Time series of ρ̂ vs M (check convergence)

**S4.** Sensitivity analysis
- Test alternative noise models (uniform, log-normal)
- Test model misspecification (fit linear when true is nonlinear)

**S5.** Document noise interpretation
- What does σ_e = 0.2 mean in practical terms?
- E.g., "Average propensity error of X percentage points"

### MAY (Optional Enhancements)

**O1.** Compare to bootstrap (no AIPW)
- Does simple importance weighting degrade similarly?

**O2.** Add Q_m-specific nuisance refitting
- Current plan: Fit once under P₀, reweight
- Alternative: Refit for each Q_m (very expensive)

**O3.** Test on all 4 DGPs
- Currently planning DGP 1 only
- Extend to DGP 2, 4, 5 if resources allow

**O4.** Extreme confounding regime
- α₁ = 1.0 or higher (near-violations of overlap)

---

## Theoretical Predictions (What We Should See)

### Scenario 0: Oracle (Baseline)
- **Bias:** O(n^(-1/2)) from sampling variability only
- **Coverage:** ≈ 95% for all n ≥ 500
- **Implication:** Validates implementation

### Scenario 1: Propensity Noise Only

**α_e = 0 (Fixed noise):**
- Bias does NOT vanish (converges to wrong limit)
- Coverage → 0 as n → ∞ (gets worse with more data!)
- Demonstrates need for vanishing noise

**α_e = 0.25 (Slow convergence):**
- Bias = O(n^(-0.25)) → shrinks very slowly
- Need n > 10,000 for acceptable bias
- Coverage poor until very large n

**α_e = 0.5 (Standard rate):**
- Bias = O(n^(-0.5)) → vanishes like sampling error
- Coverage ≈ 95% for n ≥ 2000
- Theory: Sufficient for √n-consistency

**α_e = 0.75 (Fast convergence):**
- Bias = O(n^(-0.75)) → vanishes faster than sampling error
- Coverage ≈ 95% even at n = 500
- Nearly indistinguishable from oracle

### Scenario 2: Outcome Noise Only

Same patterns as Scenario 1, but for outcome regressions.

### Scenario 3: Both Noisy (Double Robustness)

**Key theoretical result:** AIPW is √n-consistent if **α_e + α_μ > 0.5**

**Predicted behavior:**
- **(α_e=0, α_μ=0):** Both fixed → complete failure
- **(α_e=0.25, α_μ=0.25):** Sum = 0.5 (boundary) → very slow convergence
- **(α_e=0.5, α_μ=0):** Propensity OK alone → good coverage
- **(α_e=0, α_μ=0.5):** Outcome OK alone → good coverage
- **(α_e=0.5, α_μ=0.5):** Both at standard rate → excellent
- **(α_e=0.75, α_μ=0.75):** Both fast → nearly oracle

**Visualization:** Heatmap of coverage rate as function of (α_e, α_μ)
- Expect good coverage in upper-right region where α_e + α_μ > 0.5
- Diagonal line α_e + α_μ = 0.5 is the boundary

### Role of Noise Constant c

- Larger c → larger finite-sample bias
- But c does NOT affect asymptotic rate (that's determined by α)
- Example: c=2 with α=0.5 still converges at rate n^(-0.5), just with larger constant

**Expected pattern:**
- At n=500: c=2 has much larger bias than c=0.5
- At n=10000: c=2 and c=0.5 have similar bias (both small)

## Success Criteria

**Criterion 1: Oracle works**
- Oracle AIPW has |bias| < 0.05 across all settings
- Oracle coverage ∈ [93%, 97%]

**Criterion 2: Noise thresholds identified**
- For each sample size, identify σ_e and σ_μ where:
  - Bias exceeds 0.05
  - Coverage drops below 93%

**Criterion 3: Practical guidance**
- Can recommend: "For n=1000, ensure propensity model R² > X"
- Or: "Avoid AIPW-based correlation if σ_e > Y"

**Criterion 4: Reproducibility**
- All results reproducible from saved .rds files
- Code runs without manual intervention
- Documentation sufficient for replication

---

## Open Questions / Design Choices

### Q1: How to parametrize noise?

**Option A:** Noise on predictions
```
e_est(X) = clip(e_true(X) + ε, 0.01, 0.99)
```
- **Pro:** Direct interpretation (absolute error)
- **Con:** May violate [0,1] bounds

**Option B:** Noise on logit scale (current plan)
```
e_est(X) = expit(logit(e_true(X)) + ε)
```
- **Pro:** Respects [0,1] bounds
- **Con:** Harder to interpret (error is relative to baseline)

**Decision:** ✓ Use Option B (logit scale) for propensity to respect bounds. Use Option A (direct) for outcome regressions (unbounded).

**Noise scaling:** ε ~ N(0, σ²(n)) where σ(n) = c · n^(-α)
- Tests asymptotic theory: noise should vanish at rate n^(-α)
- α = 0: Fixed noise (no convergence)
- α = 0.5: Standard √n rate
- α = 0.75: Fast convergence

### Q2: Should noise be X-specific or global?

**Option A:** Global noise (same ε for all X)
```
e_est(X) = expit(logit(e_true(X)) + ε)  where ε ~ N(0, σ²)
```

**Option B:** X-specific noise (independent ε_k per level)
```
e_est(X) = expit(logit(e_true(X)) + ε_X)  where ε_X ~ N(0, σ²)
```

**Decision:** Use Option B (X-specific) to allow heterogeneous misspecification.

### Q3: What if estimated e(X) doesn't match true prevalence?

Example: True overall P(A=1) = 0.5, but noisy e(X) averages to 0.53.

**Options:**
- **Ignore:** Let it mismatch (more realistic)
- **Rescale:** Adjust e_est(X) to match true prevalence

**Decision:** ✓ **No prevalence matching** - let noise create natural misalignment (more realistic)

### Q4: How to handle extreme estimated propensities?

If noise creates e_est(X) = 0.001 or 0.999, AIPW weights explode.

**Options:**
- **Clip:** e_est(X) ∈ [0.01, 0.99] (current plan)
- **Reject:** Regenerate noise if any e_est < 0.05
- **Trim:** Drop observations with extreme weights

**Decision:** Use clipping (0.01, 0.99) to mimic trimming in practice.

### Q5: Sample size grid - how many values?

Current (revised design): n ∈ {500, 1000, 2000, 5000, 10000}

**Rationale:**
- Need range to test asymptotic behavior (noise vanishing as n → ∞)
- Five points allow clear visualization of convergence curves
- 10000 tests whether "asymptopia" is reached in practice

**Alternative:** n ∈ {500, 2000, 10000} (3 values, reduces settings by ~40%)

**Decision:** ✓ Use 5 sample sizes to clearly demonstrate convergence rates

---

## Clarity Status

| Aspect | Status | Notes |
|--------|--------|-------|
| DGP structure | CLEAR | Use DGP 1 with added confounding |
| Propensity mechanism | CLEAR | e(X) = expit(α₀ + α₁·X) |
| Noise model (propensity) | CLEAR | Logit-scale Gaussian, X-specific, σ_e(n) = c_e · n^(-α_e) |
| Noise model (outcome) | CLEAR | Direct Gaussian, X-specific, σ_μ(n) = c_μ · n^(-α_μ) |
| Parameter grid | CLEAR | 5 n values, 4 α values, 3 c values, 3 confounding |
| Sample size range | CLEAR | n ∈ {500, 1000, 2000, 5000, 10000} |
| Convergence rates | CLEAR | α ∈ {0, 0.25, 0.5, 0.75} |
| Noise constants | CLEAR | c ∈ {0.5, 1.0, 2.0} |
| Prevalence matching | CLEAR | No matching - let noise create natural misalignment |
| Extreme propensity handling | CLEAR | Clip e_est(X) ∈ [0.01, 0.99] |
| Computational budget | ASSUMED | 307k reps (~50 CPU hours, feasible on O2 with parallelization) |
| Analysis outputs | CLEAR | Bias/coverage vs n curves for each α, heatmaps for α_e × α_μ |

---

## Next Steps (After Approval)

1. **Implement observational DGP:** Add confounding to data generator
2. **Validate oracle AIPW:** Verify unbiased with true nuisances
3. **Implement noise generators:** Propensity and outcome noise functions
4. **Run pilot:** 10 reps × 10 settings to check feasibility
5. **Decide on grid:** Reduce settings if pilot suggests infeasibility
6. **Full simulation:** Run 500 reps per setting (O2 cluster)
7. **Analysis:** Generate bias/coverage curves and guidance
8. **Write-up:** Document findings for paper

---

## Estimated Effort

**Implementation:** 5-7 hours
- Observational DGP with confounding: 1 hour
- n^(-α) noise generators: 1-2 hours (need to implement scaling correctly)
- Oracle AIPW validation: 1 hour
- Simulation loop (nested over n, α, c, confounding): 1-2 hours
- Analysis scripts (convergence curves, heatmaps): 1-2 hours

**Computation:**
- Pilot (10 reps × 20 settings): ~10-15 minutes local
- Full (500 reps × 615 settings): ~50-60 CPU hours
  - With adaptive M: possibly less
  - On O2 with 30-40 cores: ~1.5-2 hours wall time
- **Alternative reduced grid:**
  - 200 reps × 615 settings: ~20-25 CPU hours (~45 min wall time on O2)
  - Scenario 3 only (240 settings) × 500 reps: ~20 CPU hours (~40 min wall time)

**Analysis & Write-up:** 3-4 hours
- More complex analysis (convergence rates, theory validation)
- Multiple plots per scenario

**Total:** ~9-13 hours (implementation + analysis)
**Computation:** ~1.5-2 hours wall time on O2

---

## References

- Proof: `inst/paper/proof_asymptotic_normality.tex` (lines 217-231 for AIPW IF)
- Current implementation: `R/tv_ball_correlation_IF.R`
- DGP specification: `cluster/config/dgp_specifications.yaml`
- Session notes: `session_notes/2026-05-08.md` (AIPW discussion)

---

## Approvals

- [x] User approves overall design
- [x] User approves DGP (confounding mechanism)
- [x] User requests noise scaling with n^(-α) (REVISED)
- [x] User requests range of sample sizes (REVISED)
- [ ] User approves revised parameter grid
- [ ] User approves computational scope (307k reps or reduced alternative)

**Status:** REVISED - Awaiting approval on revised design

**Key design changes from previous version:**
- ~~Single n=5000~~ → **Range: n ∈ {500, 1000, 2000, 5000, 10000}**
- ~~Fixed noise levels~~ → **Noise scales as σ(n) = c · n^(-α)**
- **Convergence rates:** α ∈ {0, 0.25, 0.5, 0.75} to test asymptotic theory
- **Noise constants:** c ∈ {0.5, 1.0, 2.0} to test magnitude sensitivity
- ~~84 settings~~ → **615 settings** (or reduced alternatives)
- ~~42k reps~~ → **307k reps** (or 123k with 200 reps, or focus on Scenario 3 only)

**Key decisions (unchanged):**
- No prevalence matching (let noise create natural misalignment)
- Clip extreme propensities: e_est(X) ∈ [0.01, 0.99]
- X-specific noise (independent across levels)
- Logit-scale noise for propensities, direct noise for outcomes

**Options to reduce scope if needed:**
1. Use 200 reps instead of 500 → 123k total reps (~20-25 CPU hours)
2. Use 3 sample sizes (500, 2000, 10000) → ~185k reps (~30 CPU hours)
3. Focus on Scenario 3 only (both noisy) → 120k reps (~20 CPU hours)
4. Coarser grids: 3 α values, 2 c values → ~200k reps (~33 CPU hours)
