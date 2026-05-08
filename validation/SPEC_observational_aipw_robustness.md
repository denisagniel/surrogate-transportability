# Specification: Observational AIPW Robustness Simulation

**Date:** 2026-05-08
**Status:** APPROVED
**Purpose:** Assess robustness of AIPW-based correlation inference to nuisance function misspecification

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

## Research Questions

**RQ1:** Does oracle AIPW (true nuisances) recover true correlation unbiasedly?
- **Metric:** |E[ρ̂_oracle] - ρ_true| < 0.05

**RQ2:** How does nuisance noise affect bias?
- **Metric:** Bias vs noise level curve
- **Threshold:** Identify noise level where |bias| > 0.05

**RQ3:** How does nuisance noise affect coverage?
- **Metric:** Coverage rate vs noise level
- **Threshold:** Identify noise level where coverage < 93%

**RQ4:** Which nuisance (propensity or outcome) matters more?
- **Design:** Vary e(X) noise holding μ_a(X) fixed, and vice versa
- **Metric:** Compare bias curves

**RQ5:** Does sample size mitigate nuisance noise?
- **Design:** Test n ∈ {500, 1000, 2000, 5000}
- **Hypothesis:** Larger n → more robust to nuisance noise

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

**Scenario 0: Oracle (Baseline)**
- Use true e(X), true μ_a^S(X), true μ_a^Y(X)
- No estimation error
- **Purpose:** Establish best-case performance

**Scenario 1: Propensity Noise Only**
- e_est(X) = expit(logit(e_true(X)) + ε_e) where ε_e ~ N(0, σ_e²)
- Use true μ_a^S(X), true μ_a^Y(X)
- **Noise levels:** σ_e ∈ {0, 0.1, 0.2, 0.3, 0.5, 1.0}
- **Purpose:** Isolate propensity misspecification

**Scenario 2: Outcome Noise Only**
- Use true e(X)
- μ_est^a(X) = μ_true^a(X) + ε_μ where ε_μ ~ N(0, σ_μ²)
- **Noise levels:** σ_μ ∈ {0, 0.1, 0.2, 0.5, 1.0, 2.0}
- **Purpose:** Isolate outcome regression misspecification

**Scenario 3: Both Noisy**
- e_est(X) = expit(logit(e_true(X)) + ε_e)
- μ_est^a(X) = μ_true^a(X) + ε_μ
- **Grid:** σ_e × σ_μ (4×4 = 16 combinations)
- **Purpose:** Realistic scenario (both nuisances estimated)

### Simulation Parameters

**Fixed:**
- λ = 0.3 (TV ball radius)
- M = 500 (future studies, may use adaptive M for efficiency)
- α = 0.05 (confidence level)
- N_reps = 500 per setting
- **n = 5000** (large sample to ensure good CATE estimation)

**Varied:**
- Confounding: α₁ ∈ {0, 0.3, 0.6}
- Noise levels: σ_e, σ_μ (see scenarios)

**Total settings:**
- Scenario 1: 6 noise levels × 3 confounding = 18 settings
- Scenario 2: 6 noise levels × 3 confounding = 18 settings
- Scenario 3: 16 combinations × 3 confounding = 48 settings
- **Total: 84 settings × 500 reps = 42,000 replications**

**Rationale for n=5000:**
- From CATE validation: n≥5000 ensures max |bias| < 0.11
- Large enough to isolate nuisance noise from sampling variability
- Can explore sample size sensitivity in follow-up if needed

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

**Decision:** Use Option B (logit scale) for propensity to respect bounds. Use Option A (direct) for outcome regressions (unbounded).

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

### Q5: Sample size grid - too fine?

Current: n ∈ {500, 1000, 2000, 5000}

**Alternative:** n ∈ {1000, 5000} (2 levels only, reduce total settings by half)

**Decision:** ✓ **n = 5000 only** - single large sample to ensure good CATE estimation and isolate nuisance effects

---

## Clarity Status

| Aspect | Status | Notes |
|--------|--------|-------|
| DGP structure | CLEAR | Use DGP 1 with added confounding |
| Propensity mechanism | CLEAR | e(X) = expit(α₀ + α₁·X) |
| Noise model (propensity) | CLEAR | Logit-scale Gaussian, X-specific |
| Noise model (outcome) | CLEAR | Direct Gaussian, X-specific |
| Parameter grid | CLEAR | n=5000 only, 84 settings total |
| Noise interpretation | CLEAR | X-specific independent noise |
| Prevalence matching | CLEAR | No matching - let noise create natural misalignment |
| Extreme propensity handling | CLEAR | Clip e_est(X) ∈ [0.01, 0.99] |
| Computational budget | CLEAR | 42k reps (~7 CPU hours, feasible) |
| Analysis outputs | CLEAR | Bias/coverage curves, heatmaps |

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

**Implementation:** 4-6 hours
- Observational DGP: 1 hour
- Noise generators: 1 hour
- Oracle AIPW validation: 1 hour
- Simulation loop: 1 hour
- Analysis scripts: 1-2 hours

**Computation:**
- Pilot (10 reps × 10 settings): ~5 minutes local
- Full (500 reps × 84 settings): ~7 hours CPU (~30-40 min wall time on O2 with 12-15 cores)

**Analysis & Write-up:** 2-3 hours

**Total:** ~7-10 hours

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
- [x] User approves noise model choices
- [x] User approves parameter grid: **n=5000 only**
- [x] User resolves open questions: **No prevalence matching**

**Status:** APPROVED - Ready for implementation

**Key decisions:**
- Single sample size: n = 5000
- No prevalence matching (let noise create natural misalignment)
- Clip extreme propensities: e_est(X) ∈ [0.01, 0.99]
- X-specific noise (independent across levels)
- Total: 84 settings × 500 reps = 42,000 replications (~7 CPU hours)
