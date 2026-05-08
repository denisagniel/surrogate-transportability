# PILOT: Observational AIPW Robustness Simulation

**Date:** 2026-05-08
**Status:** APPROVED
**Purpose:** Test computational feasibility and validate implementation before full study

---

## Pilot Design: Minimal Representative Grid

### Goals

1. **Validate implementation:** Oracle AIPW works correctly
2. **Test computational timing:** How long per replication at each n?
3. **Check key theoretical predictions:**
   - α = 0 should fail
   - α = 0.5 should work
   - α_e + α_μ > 0.5 boundary in Scenario 3
4. **Identify issues before full run**

### Pilot Parameter Grid

**Fixed (same as full study):**
- λ = 0.3
- M = 500 (adaptive)
- α = 0.05
- DGP 1 with confounding

**Reduced grid:**
- **Sample sizes:** n ∈ {500, 2000, 5000} (3 values, covers range)
- **Confounding:** α₁ = 0.3 only (1 value, moderate confounding)
- **Convergence rates:** α ∈ {0, 0.5} (2 values, test extremes)
- **Noise constants:** c = 1.0 only (1 value, middle magnitude)
- **Replications:** 20 per setting (enough to estimate mean time)

### Pilot Settings

**Scenario 0: Oracle**
- 3 n values × 1 confounding = **3 settings**

**Scenario 1: Propensity noise only**
- 3 n × 1 α₁ × 2 α_e × 1 c_e = **6 settings**

**Scenario 2: Outcome noise only**
- 3 n × 1 α₁ × 2 α_μ × 1 c_μ = **6 settings**

**Scenario 3: Both noisy**
- 3 n × 1 α₁ × 2 α_e × 2 α_μ × 1 c = **12 settings**
- Tests 4 combinations: (0,0), (0,0.5), (0.5,0), (0.5,0.5)

**Total: 27 settings × 20 reps = 540 replications**

**Expected time:**
- If ~1 min per rep at n=5000: ~9 hours CPU
- With 4-6 cores: ~1.5-2 hours wall time
- Much faster at smaller n

---

## Pilot Success Criteria

### SC1: Implementation Validation

**Oracle scenario:**
- [ ] |Bias| < 0.05 for all n
- [ ] Coverage ∈ [80%, 100%] (wide range for n=20)
- [ ] Code runs without errors

**If fails:** Fix implementation before proceeding

### SC2: Theoretical Predictions

**Fixed noise (α = 0):**
- [ ] Bias does NOT decrease with n
- [ ] Larger bias than α = 0.5 case at all n

**Standard rate (α = 0.5):**
- [ ] Bias decreases with n
- [ ] Coverage improves with n

**Double robustness (Scenario 3):**
- [ ] (α_e=0, α_μ=0): Worst performance
- [ ] (α_e=0.5, α_μ=0.5): Best performance
- [ ] (α_e=0.5, α_μ=0): Better than (0,0)
- [ ] (α_e=0, α_μ=0.5): Better than (0,0)

**If fails:** Investigate before full run

### SC3: Computational Feasibility

**Timing:**
- [ ] Mean time per rep at each n
- [ ] Convergence rate (% converged in M_max)
- [ ] Extrapolate to full study time

**If too slow:**
- Reduce M_max
- Reduce M_increment
- Consider reducing full grid

### SC4: Practical Issues

- [ ] No numerical instability (NaN, Inf)
- [ ] Extreme propensity clipping works
- [ ] Noise generation produces sensible values
- [ ] Memory usage acceptable

**If issues found:** Fix before full run

---

## Pilot Outputs

### Immediate Diagnostics (Console)

For each setting:
```
Setting: n=2000, α₁=0.3, scenario=3, α_e=0.5, α_μ=0
  Mean ρ̂: 0.685 (true: 0.691)
  Mean SE: 0.042
  Coverage: 85% (17/20)
  Mean time: 2.3 min
  Converged: 100% (20/20)
```

### Summary Table

| Scenario | n    | α_e | α_μ | Bias   | Cov  | Time  |
|----------|------|-----|-----|--------|------|-------|
| Oracle   | 500  | -   | -   | -0.003 | 90%  | 1.2m  |
| Oracle   | 2000 | -   | -   | -0.001 | 95%  | 2.8m  |
| Oracle   | 5000 | -   | -   | 0.002  | 90%  | 5.1m  |
| Prop     | 500  | 0   | -   | 0.125  | 45%  | 1.3m  |
| Prop     | 500  | 0.5 | -   | 0.018  | 85%  | 1.2m  |
| ...      | ...  | ... | ... | ...    | ...  | ...   |

### Plots (Quick)

1. **Bias vs n** for each (scenario, α) combination
2. **Coverage vs n** for each combination
3. **Heatmap:** Coverage for Scenario 3 (2×2 grid: α_e × α_μ)
4. **Time vs n** (check computational scaling)

---

## Pilot Implementation

### File: `validation/pilot_aipw_robustness.R`

**Structure:**
```r
# 1. Load packages
library(surrogateTransportability)

# 2. Define pilot grid
pilot_grid <- expand.grid(
  scenario = c("oracle", "propensity", "outcome", "both"),
  n = c(500, 2000, 5000),
  alpha_1 = 0.3,
  alpha_e = c(0, 0.5),
  alpha_mu = c(0, 0.5),
  c_e = 1.0,
  c_mu = 1.0,
  rep = 1:20
)

# Filter to valid combinations (e.g., oracle has no noise)
# ...

# 3. Run simulation
results <- data.frame()

for (i in 1:nrow(pilot_grid)) {
  setting <- pilot_grid[i, ]

  # Time the replication
  start_time <- Sys.time()

  # Generate data with confounding
  data <- generate_observational_dgp(
    n = setting$n,
    alpha_1 = setting$alpha_1,
    # DGP 1 parameters from yaml
  )

  # Generate noisy nuisances
  nuisances <- generate_noisy_nuisances(
    data = data,
    scenario = setting$scenario,
    alpha_e = setting$alpha_e,
    alpha_mu = setting$alpha_mu,
    c_e = setting$c_e,
    c_mu = setting$c_mu,
    n = setting$n
  )

  # Run AIPW estimation
  result <- tv_ball_correlation_IF(
    data = data,
    lambda = 0.3,
    method = "aipw",
    e_hat = nuisances$e_hat,
    mu_hat = nuisances$mu_hat,
    # ... other args
  )

  end_time <- Sys.time()

  # Store results
  results <- rbind(results, data.frame(
    setting = i,
    n = setting$n,
    scenario = setting$scenario,
    alpha_e = setting$alpha_e,
    alpha_mu = setting$alpha_mu,
    rho_hat = result$rho_hat,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    converged = result$converged,
    M_final = result$M_final,
    time_sec = as.numeric(end_time - start_time, units = "secs")
  ))

  # Progress
  if (i %% 10 == 0) {
    cat(sprintf("Completed %d/%d (%.1f%%)\n", i, nrow(pilot_grid), 100*i/nrow(pilot_grid)))
  }
}

# 4. Analyze and report
source("validation/analyze_pilot_results.R")
```

### File: `validation/analyze_pilot_results.R`

**Generates:**
- Summary table (bias, coverage, time by setting)
- Diagnostic plots (bias vs n, coverage vs n, heatmap)
- Success/failure assessment against criteria
- Extrapolation to full study time

---

## Decision Points After Pilot

### If pilot succeeds (all criteria met):

**Proceed to full study with:**
- Same implementation (validated)
- Original full grid or reduced alternatives
- Estimated wall time from pilot extrapolation

### If pilot reveals issues:

**Common issues and fixes:**

**Issue 1: Oracle bias > 0.05**
- **Diagnosis:** Implementation bug
- **Fix:** Debug AIPW computation, check IF formula
- **Re-run pilot after fix**

**Issue 2: Computation too slow (>10 min per rep at n=5000)**
- **Diagnosis:** M_max too large or adaptive M not working
- **Fix:** Reduce M_max from 5000 to 2000, tighten tolerance
- **Re-run pilot with faster settings**

**Issue 3: Convergence failures (>10% don't converge)**
- **Diagnosis:** M_max insufficient or tolerance too tight
- **Fix:** Increase M_max or loosen tolerance
- **Re-run pilot**

**Issue 4: Theoretical predictions violated**
- **Example:** α=0.5 doesn't improve with n
- **Diagnosis:** Noise scaling formula wrong or nuisance generation bug
- **Fix:** Debug noise generation, verify σ(n) = c·n^(-α)
- **Re-run pilot after fix**

**Issue 5: Numerical instability (NaN/Inf)**
- **Diagnosis:** Extreme propensities not clipped correctly
- **Fix:** Strengthen clipping logic, add validation
- **Re-run pilot**

### Pivot options if infeasible:

**Option A: Reduce full grid**
- Fewer α values: {0, 0.5} only
- Fewer c values: c = 1.0 only
- Fewer n values: {500, 2000, 5000} only

**Option B: Sequential approach**
- Run Scenarios 0 and 3 first (oracle + both noisy)
- If interesting, add Scenarios 1 and 2

**Option C: Focus on key question**
- Only Scenario 3 with full (α_e, α_μ) grid
- Tests double robustness thoroughly
- Skip single-nuisance scenarios

---

## Pilot Timeline

**Implementation:** 2-3 hours
- Observational DGP with confounding: 1 hour
- Noise generators with n^(-α) scaling: 1 hour
- Pilot script and analysis: 1 hour

**Computation:** 1.5-3 hours (depends on actual timing)

**Analysis and decision:** 30 min

**Total:** 4-6.5 hours

---

## File Outputs

**Generated files:**
```
validation/
  pilot_aipw_robustness.R           # Main pilot script
  analyze_pilot_results.R            # Analysis script
  results/
    pilot_aipw_robustness_raw.rds    # Raw results
    pilot_aipw_robustness_summary.csv # Summary table
  figures/
    pilot_bias_vs_n.pdf              # Convergence plots
    pilot_coverage_vs_n.pdf          # Coverage plots
    pilot_heatmap_scenario3.pdf      # Double robustness heatmap
    pilot_time_vs_n.pdf              # Computational scaling
```

---

## Approval

- [x] User approves pilot design
- [x] User approves 540 replications (~1.5-3 hrs)
- [x] User approves decision criteria

**Status:** APPROVED - Ready to implement pilot

**Next steps:**
1. Implement observational DGP generator
2. Implement noise generator with n^(-α) scaling
3. Run pilot (540 reps)
4. Analyze results
5. Decide on full study scope based on pilot findings
