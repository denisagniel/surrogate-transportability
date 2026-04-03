# Weekend Validation Plan (Option B: Breadth)

**Goal:** Complete all three validation studies with moderate replication counts for comprehensive coverage assessment.

## Computational Budget

- **Time available:** 60 hours (Friday evening → Sunday evening)
- **Parallel capacity:** 9 cores
- **Total compute:** 5,800 replications in ~54 hours

## Studies

### 1. Covariate Shift Validation
- **4 scenarios × 500 reps = 2,000 reps**
- Scenarios: small (60/40), moderate (70/30), large (80/20), extreme (90/10)
- Tests: Does method work when truth = covariate shift?
- Compute: ~19 hours

### 2. Selection Bias Validation
- **4 scenarios × 500 reps = 2,000 reps**
- Scenarios: weak/moderate/strong outcome-favorable, moderate treatment-responders
- Tests: Does method work when truth = selection mechanism?
- Compute: ~19 hours

### 3. Dirichlet Misspecification
- **6 scenarios × 300 reps = 1,800 reps**
- Scenarios: α ∈ {0.1, 0.5, 1.0, 2.0, 5.0, 10.0}
- Tests: Sensitivity to innovation distribution misspecification
- Compute: ~16 hours

## Timeline

### Friday Evening (Now)
```bash
# Launch parallel validation
bash sims/scripts/run_parallel_validation.sh > logs/validation_master.log 2>&1 &
```

Runs overnight and all day Saturday. **Completes: Sunday morning ~8-10am**

### Saturday
**While validation runs:**
- Work on other tasks (theory, writing, figures)
- Check progress periodically:
  ```bash
  bash sims/scripts/monitor_validation.sh
  ```

### Sunday Morning (when complete)
**Aggregate results (30 minutes):**
```bash
# Aggregate each study
Rscript sims/scripts/aggregate_results.R --study-type covariate_shift
Rscript sims/scripts/aggregate_results.R --study-type selection_bias
Rscript sims/scripts/aggregate_results.R --study-type dirichlet_misspec

# Create combined report
Rscript sims/scripts/create_validation_report.R
```

### Sunday (Rest of Day)
**Analysis & Writing:**
- Review coverage rates and figures
- Draft validation section (Section 5.X)
- Create publication-quality figures
- Update abstract and contributions
- Document findings

## Expected Outputs

### Quantitative
- Coverage rates by scenario (target: ≥90%)
- CI vs quantile interval comparison
- Calibration plots (true vs estimated φ)
- 12+ publication-ready figures

### Qualitative
- Paper section draft (~3-4 pages)
- Summary tables for main text
- Detailed results for appendix
- Substantive interpretation of λ

## Quality with 500 Reps

**Standard error on 95% coverage:**
- SE = √(0.95 × 0.05 / 500) = 0.0097 ≈ 0.01
- 95% CI: [0.93, 0.97]

**Conclusion:** 500 reps is adequate to detect coverage problems (e.g., if true coverage is 90%, we'll detect it with high probability). Not as precise as 1000 reps, but defensible for comprehensive study.

## Monitoring

Check progress any time:
```bash
bash sims/scripts/monitor_validation.sh
```

View master log:
```bash
tail -f logs/validation_master.log
```

Check specific scenario:
```bash
tail logs/parallel_validation/covariate_shift_small_rep0001.log
```

## Contingency

If any failures occur:
```bash
# Rerun specific replication
Rscript sims/scripts/run_single_replication.R \
  --study-type covariate_shift \
  --scenario small \
  --replication 42 \
  --output-dir sims/results/reps/covariate_shift
```

## What This Enables

By Sunday evening you'll have:

✓ **Complete empirical validation** across all three mechanisms
✓ **Defensible coverage assessment** (500 reps per scenario)
✓ **Publication-ready results** for paper Section 5
✓ **Comprehensive understanding** of method robustness

## Launch Now

```bash
cd /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability
bash sims/scripts/run_parallel_validation.sh > logs/validation_master.log 2>&1 &
```

Then check progress Saturday morning!
