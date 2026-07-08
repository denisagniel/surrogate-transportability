# Simulation Implementation Status

**Created:** 2026-05-27
**Last Updated:** 2026-05-27 16:35

---

## Executive Summary

**Status:** Tier 1 infrastructure complete, ready for λ-sensitivity simulations

**Progress:**
- ✅ Figure 1 (histograms): Complete
- ✅ Figure 2 (scatter plots): Complete
- ⚠️ Figure 3 (λ-sensitivity): Infrastructure ready, simulations needed
- ✅ Table 1-3: Complete

**Next Steps:**
1. Test λ-sensitivity code locally (10 reps, ~10 min)
2. Submit to cluster (20,000 reps, ~28 hours with 40 cores)
3. Generate Figure 3 from results (~30 min)

**Blocking:** Need to run 20,000 new simulations for Figure 3

---

## Tier 1: Essential (Publication-Ready Minimum)

### ✅ Completed

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| Table 1: DGP specs | ✅ Complete | `inst/paper/tables/table1_dgps.tex` | Generated 2026-05-27 |
| Table 2: Performance | ✅ Complete | `inst/paper/tables/table2_performance.tex` | Generated 2026-05-27 |
| Table 3: Timing | ✅ Complete | `inst/paper/tables/table3_timing.tex` | Generated 2026-05-27 |
| Figure 1: Histograms | ✅ Complete | `inst/paper/figures/figure1_histograms.pdf` | Generated 2026-05-27 |
| Figure 2: Scatter plots | ✅ Complete | `inst/paper/figures/figure2_scatterplots.pdf` | Generated 2026-05-27 |

### ⚠️ In Progress

| Component | Status | Blocking Issue | Solution |
|-----------|--------|----------------|----------|
| Figure 3: λ-sensitivity | Infrastructure ready | Need 20,000 new simulations | Run cluster array job |

**Figure 3 Requirements:**
- Design: λ ∈ {0.1, 0.2, 0.3, 0.4, 0.5} × 4 DGPs
- Replications: 1000 per condition = 20,000 total
- Runtime: 28 hours (40 cores) or 140 hours (8 cores local)
- Scientific value: Essential for paper - distinguishes robust vs fragile transportability

---

## Infrastructure Created

### Configuration Files

1. **cluster/config/lambda_sensitivity_specs.yaml**
   - Defines 20 conditions (5 λ × 4 DGPs)
   - Specifies 1000 reps per condition
   - Expected runtime estimates

### SLURM Scripts

2. **cluster/slurm/lambda_sensitivity_array.slurm**
   - Array job with 20 tasks (one per condition)
   - 1.5 hours per task, 4GB RAM
   - Automatic checkpoint every 50 reps

3. **cluster/slurm/launch_lambda_sensitivity.sh**
   - Launcher script for array job
   - Monitors progress and reports status

### R Scripts

4. **sims/scripts/lambda_sensitivity_study.R**
   - Main simulation loop for one condition
   - Handles checkpointing and resume
   - Command-line interface with optparse

5. **sims/scripts/generate_figure3_lambda_sensitivity.R**
   - Loads results from all conditions
   - Computes summary statistics
   - Generates 4-panel plot with 95% CIs
   - Output: `inst/paper/figures/figure3_lambda_sensitivity.pdf`

6. **sims/scripts/lambda_sensitivity_local_test.R**
   - Quick test with 10 reps per condition
   - Verifies code before cluster submission
   - Estimates full runtime

---

## Execution Plan

### Step 1: Local Test (Optional but Recommended)

**Purpose:** Verify code works before cluster submission

```bash
Rscript sims/scripts/lambda_sensitivity_local_test.R
```

**Expected:**
- 6 conditions (3 λ × 2 DGPs) × 10 reps = 60 replications
- Runtime: ~10 minutes
- Output: Mean ρ̂ for each condition

### Step 2: Cluster Submission

**Purpose:** Run full 20,000 replications

```bash
# From project root on O2 cluster
bash cluster/slurm/launch_lambda_sensitivity.sh
```

**Monitor progress:**
```bash
squeue -u ${USER}
ls -lt cluster/results/lambda_sensitivity/*.rds | wc -l  # Should be 20
```

**Expected:**
- 20 array tasks (one per condition)
- Runtime: ~1.5 hours (parallel execution)
- Output: 20 .rds files in `cluster/results/lambda_sensitivity/`

### Step 3: Generate Figure 3

**Purpose:** Create λ-sensitivity plot from results

```bash
Rscript sims/scripts/generate_figure3_lambda_sensitivity.R
```

**Expected:**
- Reads all 20 result files
- Computes summary statistics (mean, SE, CI)
- Generates 4-panel plot
- Output: `inst/paper/figures/figure3_lambda_sensitivity.pdf`

---

## Expected Outcomes

### Scientific Insights

**Robust transportability (flat ρ̂(λ) profiles):**
- DGP 1: Moderate positive correlation stable across λ
- DGP 4: Perfect correlation despite low PTE
- DGP 5: Perfect correlation despite undefined PTE

**Fragile transportability (declining profile):**
- DGP 2: Strong negative correlation weakens as λ increases
- Cause: Opposite-signed effect modification

### Statistical Validation

**Expected performance:**
- Bias < 0.01 for all conditions
- Coverage: 93-97% across all (λ, DGP) pairs
- SE calibration: empirical SE ≈ estimated SE

---

## Files Created (2026-05-27)

### New Files

```
cluster/config/lambda_sensitivity_specs.yaml          (Configuration)
cluster/slurm/lambda_sensitivity_array.slurm          (SLURM job)
cluster/slurm/launch_lambda_sensitivity.sh            (Launcher)
sims/scripts/lambda_sensitivity_study.R               (Main simulation)
sims/scripts/generate_figure3_lambda_sensitivity.R    (Figure generator)
sims/scripts/lambda_sensitivity_local_test.R          (Quick test)
SIMULATION_IMPLEMENTATION_STATUS.md                   (This file)
```

### Modified Files

```
inst/paper/figures/figure2_scatterplots.pdf           (Regenerated)
```

---

## Tier 2: Enhanced (Future Work)

### Not Yet Started

**Sample size robustness (Tier 2A):**
- Design: n ∈ {500, 1000, 5000, 10000} × 4 DGPs
- Replications: 1000 per condition = 16,000 total
- Runtime: ~20 hours (cluster) or ~100 hours (local)
- Output: Supplementary figures/tables

**Geometry comparison (Tier 2B):**
- Design: TV vs χ² vs L₂ × 4 DGPs
- Replications: 1000 per condition = 12,000 total
- Runtime: ~16 hours (cluster) or ~80 hours (local)
- Output: Supplementary figures

**Assessment:** Defer until after submission or during revision

---

## Critical Path to Submission

**Current bottleneck:** Figure 3 λ-sensitivity simulations

**Timeline (with cluster access):**

| Step | Duration | Cumulative |
|------|----------|------------|
| Local test (optional) | 10 min | 10 min |
| Submit cluster job | 5 min | 15 min |
| Cluster execution | 1.5 hours | 1 hr 45 min |
| Generate Figure 3 | 30 min | 2 hr 15 min |
| Verify Section 4 complete | 15 min | 2 hr 30 min |

**Total: ~2.5 hours** (mostly waiting for cluster)

**Timeline (without cluster, 8-core local):**

| Step | Duration | Cumulative |
|------|----------|------------|
| Local test | 10 min | 10 min |
| Run locally (parallel) | 140 hours | 140 hr 10 min |
| Generate Figure 3 | 30 min | 140 hr 40 min |
| Verify Section 4 complete | 15 min | 140 hr 55 min |

**Total: ~6 days** (continuous computation)

---

## Verification Checklist

**After Figure 3 generation:**

- [ ] All 20 conditions represented (5 λ × 4 DGPs)
- [ ] DGP 2 shows declining |ρ̂(λ)| as λ increases
- [ ] DGPs 1, 4, 5 show flat profiles
- [ ] 95% CIs include true ρ for each condition
- [ ] Coverage 93-97% across all conditions
- [ ] Figure has 4 panels (one per DGP)
- [ ] Figure saved to `inst/paper/figures/figure3_lambda_sensitivity.pdf`

**Section 4 completeness:**

- [ ] Table 1: DGP specifications ✅
- [ ] Table 2: Performance metrics ✅
- [ ] Table 3: Computational cost ✅
- [ ] Figure 1: Histogram of ρ̂ across reps ✅
- [ ] Figure 2: Scatter plots of (ΔS, ΔY) ✅
- [ ] Figure 3: λ-sensitivity curves ⚠️ (blocking)

---

## Contact / Support

**Cluster access:** O2 Harvard Medical School cluster
**Module loads:** gcc/14.2.0, R/4.4.2
**Partition:** short (max 12 hours)

**If issues arise:**
1. Check SLURM logs: `cluster/slurm/logs/lambda_sens_*.out`
2. Verify package installed: `R -e "library(surrogateTransportability)"`
3. Test locally first: `Rscript sims/scripts/lambda_sensitivity_local_test.R`

---

## Summary

**What's done:** All tables, Figures 1-2, infrastructure for Figure 3
**What's needed:** Run 20,000 simulations for Figure 3
**Time required:** 2.5 hours (cluster) or 6 days (local)
**Outcome:** Complete, publication-ready Section 4 for Biometrika submission

**Recommendation:** Submit to cluster immediately - this is the critical bottleneck for paper submission.
